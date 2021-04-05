(*————————————————————————————————————————————————————————————————————————————
   Copyright (c) 2020–2021 Craig Ferguson <me@craigfe.io>
   Distributed under the MIT license. See terms at the end of this file.
  ————————————————————————————————————————————————————————————————————————————*)

open! Import

module Percentage = struct
  let clamp (lower, upper) = min upper >> max lower

  let of_float =
    let percentage x = clamp (0, 100) (Float.to_int (x *. 100.)) in
    let pp ppf x = Format.fprintf ppf "%3.0d%%" (percentage x) in
    let to_string x = Format.asprintf "%3.0d%%" (percentage x) in
    Printer.create ~string_len:4 ~to_string ~pp
end

module Bytes = struct
  let rec power = function 1 -> 1024L | n -> Int64.mul 1024L (power (n - 1))
  let conv exp = Int64.(of_int >> mul (power exp))
  let kib = conv 1
  let mib = conv 2
  let gib = conv 3
  let tib = conv 4
  let pib = conv 5

  (** Pretty-printer for byte counts *)
  let generic to_float =
    let process_components x k =
      let mantissa, unit, rpad =
        match[@ocamlformat "disable"] to_float x with
        | n when n < 1024.       -> (n                 , "B"  , "  ")
        | n when n < 1024. ** 2. -> (n /. 1024.        , "KiB", "")
        | n when n < 1024. ** 3. -> (n /. (1024. ** 2.), "MiB", "")
        | n when n < 1024. ** 4. -> (n /. (1024. ** 3.), "GiB", "")
        | n when n < 1024. ** 5. -> (n /. (1024. ** 4.), "TiB", "")
        | n when n < 1024. ** 6. -> (n /. (1024. ** 5.), "PiB", "")
        | n                      -> (n /. (1024. ** 6.), "EiB", "")
      in
      (* Round down to the nearest 0.1 *)
      let mantissa = Float.trunc (mantissa *. 10.) /. 10. in
      let lpad =
        match mantissa with
        | n when n < 10. -> "   "
        | n when n < 100. -> "  "
        | n when n < 1000. -> " "
        | _ -> ""
      in
      k ~mantissa ~unit ~rpad ~lpad
    in
    let pp ppf x =
      process_components x (fun ~mantissa ~unit ~rpad:_ ~lpad:_ ->
          Fmt.pf ppf "%.1f %s" mantissa unit)
    in
    let to_string x =
      process_components x (fun ~mantissa ~unit ~rpad ~lpad ->
          Printf.sprintf "%s%.1f %s%s" lpad mantissa unit rpad)
    in
    let string_len = 10 in
    Printer.create ~to_string ~string_len ~pp

  let of_int = generic Int.to_float
  let of_int64 = generic Int64.to_float
  let of_float = generic Fun.id
end

module Duration = struct
  let mm_ss =
    let to_string span =
      let seconds = Mtime.Span.to_s span in
      Printf.sprintf "%02.0f:%02.0f"
        (Float.div seconds 60. |> Float.floor)
        (Float.rem seconds 60. |> Float.floor)
    in
    Printer.of_to_string ~len:5 to_string
end

(*————————————————————————————————————————————————————————————————————————————
   Copyright (c) 2020–2021 Craig Ferguson <me@craigfe.io>

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
   THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.
  ————————————————————————————————————————————————————————————————————————————*)