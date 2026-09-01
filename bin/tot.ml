(** The tot CLI: check a script (types only) or run it (execute eval
    items). The existence guard makes the common missing-file case a
    clean exit 1; the residual raise-on-permission-race inside
    [In_channel.with_open_text] is a documented SPEC debt. *)

let run_file ~(exec : bool) (path : string) : int =
  match () with
  | () when not (Sys.file_exists path) ->
      print_endline (path ^ ": no such file");
      1
  | () ->
      let src = In_channel.with_open_text path In_channel.input_all in
      Tot_surface.Run.script ~exec src
      |> Result.fold
           ~ok:(fun lines ->
             List.iter print_endline lines;
             0)
           ~error:(fun e ->
             print_endline (path ^ ":" ^ Tot_surface.Serror.to_string e);
             1)

let () =
  match Array.to_list Sys.argv with
  | _exe :: "check" :: [ path ] -> Stdlib.exit (run_file ~exec:false path)
  | _exe :: "run" :: [ path ] -> Stdlib.exit (run_file ~exec:true path)
  | [] | [ _ ] | _ :: _ :: _ ->
      print_endline "usage: tot (check|run) FILE";
      Stdlib.exit 2
