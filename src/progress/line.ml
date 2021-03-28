include Line_intf
open! Import
open Segment

type nonrec 'a t = 'a t

(* Basic utilities for combining segments *)

let const s =
  let len = String.length s and len_utf8 = String.Utf8.length s in
  theta ~width:len_utf8 (fun buf -> Line_buffer.add_substring buf s ~off:0 ~len)

let const_fmt ~width pp =
  theta ~width (fun buf -> Line_buffer.with_ppf buf (fun ppf -> pp ppf))

let of_pp ~width pp =
  alpha ~width (fun buf x -> Line_buffer.with_ppf buf (fun ppf -> pp ppf x))

let pair = pair
let list ?(sep = const "  ") = List.intersperse ~sep >> Array.of_list >> array
let ( ++ ) a b = array [| a; b |]
let using f x = contramap ~f x

(* Spinners *)

let with_style_opt ~style buf f =
  match style with
  | None -> f ()
  | Some s ->
      Line_buffer.add_style_code buf s;
      let a = f () in
      Line_buffer.add_style_code buf `None;
      a

let modulo_counter : int -> (unit -> int) Staged.t =
 fun bound ->
  let idx = ref (-1) in
  Staged.inj (fun () ->
      idx := succ !idx mod bound;
      !idx)

let spinner ?color ?stages () =
  let stages, width =
    match stages with
    | None -> ([| "⠁"; "⠂"; "⠄"; "⡀"; "⢀"; "⠠"; "⠐"; "⠈" |], 1)
    | Some [] -> Fmt.invalid_arg "spinner must have at least one stage"
    | Some (x :: xs as stages) ->
        let width = String.length (* UTF8 *) x in
        ListLabels.iter xs ~f:(fun x ->
            let width' = String.length x in
            if width <> width' then
              Fmt.invalid_arg
                "spinner stages must have the same UTF-8 length. found %d and \
                 %d"
                width width');
        (Array.of_list stages, width)
  in
  let stage_count = Array.length stages in
  stateful (fun () ->
      let tick = Staged.prj (modulo_counter stage_count) in
      theta ~width (fun buf ->
          with_style_opt buf ~style:color (fun () ->
              Line_buffer.add_string buf stages.(tick ()))))

let bytes = of_pp ~width:Units.Bytes.width Units.Bytes.of_int
let bytes_int64 = of_pp ~width:Units.Bytes.width Units.Bytes.of_int64
let percentage = of_pp ~width:Units.Percentage.width Units.Percentage.of_float

let string =
  alpha_unsized (fun ~width buf s ->
      let len = String.length s in
      if len <= width () then (
        Line_buffer.add_string buf s;
        len)
      else assert false)

(* Progress bars *)

let bar_custom ~stages ~color ~color_empty width proportion buf =
  let color_empty = Option.(color_empty || color) in
  let stages = Array.of_list stages in
  let final_stage = Array.length stages - 1 in
  let width = width () in
  let bar_width = width - 2 in
  let squaresf = Float.of_int bar_width *. proportion in
  let squares = Float.to_int squaresf in
  let filled = min squares bar_width in
  let not_filled = bar_width - filled - 1 in
  Line_buffer.add_string buf "│";
  with_style_opt ~style:color buf (fun () ->
      for _ = 1 to filled do
        Line_buffer.add_string buf stages.(final_stage)
      done);
  let () =
    if filled <> bar_width then (
      let chunks = Float.to_int (squaresf *. Float.of_int final_stage) in
      let index = chunks - (filled * final_stage) in
      if index >= 0 && index < final_stage then
        with_style_opt ~style:color buf (fun () ->
            Line_buffer.add_string buf stages.(index));

      with_style_opt ~style:color_empty buf (fun () ->
          for _ = 1 to not_filled do
            Line_buffer.add_string buf stages.(0)
          done))
  in
  Line_buffer.add_string buf "│";
  width

let bar_ascii ~color ~color_empty width proportion buf =
  let color_empty = Option.(color_empty || color) in
  let width = width () in
  let bar_width = width - 2 in
  let filled =
    min (Float.to_int (Float.of_int bar_width *. proportion)) bar_width
  in
  let not_filled = bar_width - filled in
  Line_buffer.add_char buf '[';
  with_style_opt ~style:color buf (fun () ->
      for _ = 1 to filled do
        Line_buffer.add_char buf '#'
      done);
  with_style_opt ~style:color_empty buf (fun () ->
      for _ = 1 to not_filled do
        Line_buffer.add_char buf '-'
      done);
  Line_buffer.add_char buf ']';
  width

let bar ~style =
  match style with
  | `ASCII -> bar_ascii
  | `Custom stages -> bar_custom ~stages
  | `UTF8 ->
      let stages =
        [ " "; "▏"; "▎"; "▍"; "▌"; "▋"; "▊"; "▉"; "█" ]
      in
      bar_custom ~stages

let bar ?(style = `UTF8) ?color ?color_empty ?(width = `Expand) f =
  contramap ~f
    (match width with
    | `Fixed width ->
        if width < 3 then failwith "Not enough space for a progress bar";
        alpha ~width (fun buf x ->
            ignore (bar ~style ~color ~color_empty (fun _ -> width) x buf : int))
    | `Expand ->
        alpha_unsized (fun ~width ppf x ->
            bar ~style ~color ~color_empty width x ppf))

module Expert = Segment