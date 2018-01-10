
(* Copyright (C) 2017 Authors of BuckleScript
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

module A = Bs_Array 

(* external unsafe_get: 'a array -> int -> 'a = "%array_unsafe_get"
external unsafe_set: 'a array -> int -> 'a -> unit = "%array_unsafe_set" *)
external unsafe_blit :
  'a array -> int -> 'a array -> int -> int -> unit = "caml_array_blit"
external length : 'a array -> int = "%array_length"

let rec isSortedAux a i cmp last_bound = 
  (* when [i = len - 1], it reaches the last element*)
  if i = last_bound then true 
  else 
  if cmp (A.unsafe_get a i) (A.unsafe_get a (i+1)) [@bs] < 0 then 
    isSortedAux a (i + 1) cmp last_bound 
  else false 


let isSorted a cmp =
  let len = length a in 
  if len = 0 then true
  else isSortedAux a 0 cmp (len - 1)


let cutoff = 5

let merge src src1ofs src1len src2 src2ofs src2len dst dstofs cmp =
  let src1r = src1ofs + src1len and src2r = src2ofs + src2len in
  let rec loop i1 s1 i2 s2 d =
    if cmp s1 s2 [@bs] <= 0 then begin
      A.unsafe_set dst d s1;
      let i1 = i1 + 1 in
      if i1 < src1r then
        loop i1 (A.unsafe_get src i1) i2 s2 (d + 1)
      else
        unsafe_blit src2 i2 dst (d + 1) (src2r - i2)
    end else begin
      A.unsafe_set dst d s2;
      let i2 = i2 + 1 in
      if i2 < src2r then
        loop i1 s1 i2 (A.unsafe_get src2 i2) (d + 1)
      else
        unsafe_blit src i1 dst (d + 1) (src1r - i1)
    end
  in 
  loop src1ofs (A.unsafe_get src src1ofs) src2ofs (A.unsafe_get src2 src2ofs) dstofs

(* specialized for floats *)
let mergeInts (src : int array) src1ofs src1len src2 src2ofs src2len dst dstofs  =
  let src1r = src1ofs + src1len and src2r = src2ofs + src2len in
  let rec loop i1 s1 i2 s2 d =
    if  s1 <= s2  then begin
      A.unsafe_set dst d s1;
      let i1 = i1 + 1 in
      if i1 < src1r then
        loop i1 (A.unsafe_get src i1) i2 s2 (d + 1)
      else
        unsafe_blit src2 i2 dst (d + 1) (src2r - i2)
    end else begin
      A.unsafe_set dst d s2;
      let i2 = i2 + 1 in
      if i2 < src2r then
        loop i1 s1 i2 (A.unsafe_get src2 i2) (d + 1)
      else
        unsafe_blit src i1 dst (d + 1) (src1r - i1)
    end
  in 
  loop src1ofs (A.unsafe_get src src1ofs) src2ofs (A.unsafe_get src2 src2ofs) dstofs
  
(* specialized for floats *)
let mergeFloats (src : float array) src1ofs src1len src2 src2ofs src2len dst dstofs  =
  let src1r = src1ofs + src1len and src2r = src2ofs + src2len in
  let rec loop i1 s1 i2 s2 d =
    if  s1 <= s2  then begin
      A.unsafe_set dst d s1;
      let i1 = i1 + 1 in
      if i1 < src1r then
        loop i1 (A.unsafe_get src i1) i2 s2 (d + 1)
      else
        unsafe_blit src2 i2 dst (d + 1) (src2r - i2)
    end else begin
      A.unsafe_set dst d s2;
      let i2 = i2 + 1 in
      if i2 < src2r then
        loop i1 s1 i2 (A.unsafe_get src2 i2) (d + 1)
      else
        unsafe_blit src i1 dst (d + 1) (src1r - i1)
    end
  in 
  loop src1ofs (A.unsafe_get src src1ofs) src2ofs (A.unsafe_get src2 src2ofs) dstofs
  
(* [<=] alone is not enough for stable sort *)
let insertionSort src srcofs dst dstofs len cmp =
  for i = 0 to len - 1 do
    let e = (A.unsafe_get src (srcofs + i)) in
    let j = ref (dstofs + i - 1) in
    while (!j >= dstofs && cmp (A.unsafe_get dst !j) e [@bs] > 0) do
      A.unsafe_set dst (!j + 1) (A.unsafe_get dst !j);
      decr j;
    done;
    A.unsafe_set dst (!j + 1) e;
  done    

let insertionSortInts (src : int array) srcofs dst dstofs len  =
  for i = 0 to len - 1 do
    let e = (A.unsafe_get src (srcofs + i)) in
    let j = ref (dstofs + i - 1) in
    while (!j >= dstofs &&  (A.unsafe_get dst !j) > e  ) do
      A.unsafe_set dst (!j + 1) (A.unsafe_get dst !j);
      decr j;
    done;
    A.unsafe_set dst (!j + 1) e;
  done    

let insertionSortFloats (src : float array) srcofs dst dstofs len  =
  for i = 0 to len - 1 do
    let e = (A.unsafe_get src (srcofs + i)) in
    let j = ref (dstofs + i - 1) in
    while (!j >= dstofs &&  (A.unsafe_get dst !j) > e ) do
      A.unsafe_set dst (!j + 1) (A.unsafe_get dst !j);
      decr j;
    done;
    A.unsafe_set dst (!j + 1) e;
  done    

let rec sortTo src srcofs dst dstofs len cmp =
  if len <= cutoff then insertionSort src srcofs dst dstofs len cmp 
  else begin
    let l1 = len / 2 in
    let l2 = len - l1 in
    sortTo src (srcofs + l1) dst (dstofs + l1) l2 cmp;
    sortTo src srcofs src (srcofs + l2) l1 cmp;
    merge src (srcofs + l2) l1 dst (dstofs + l1) l2 dst dstofs cmp;
  end    

let rec sortToInts (src : int array) srcofs dst dstofs len  =
  if len <= cutoff then insertionSortInts src srcofs dst dstofs len  
  else begin
    let l1 = len / 2 in
    let l2 = len - l1 in
    sortToInts src (srcofs + l1) dst (dstofs + l1) l2 ;
    sortToInts src srcofs src (srcofs + l2) l1 ;
    mergeInts src (srcofs + l2) l1 dst (dstofs + l1) l2 dst dstofs ;
  end    

let rec sortToFloats (src : float array) srcofs dst dstofs len  =
  if len <= cutoff then insertionSortFloats src srcofs dst dstofs len  
  else begin
    let l1 = len / 2 in
    let l2 = len - l1 in
    sortToFloats src (srcofs + l1) dst (dstofs + l1) l2 ;
    sortToFloats src srcofs src (srcofs + l2) l1 ;
    mergeFloats src (srcofs + l2) l1 dst (dstofs + l1) l2 dst dstofs ;
  end      

let stableSortBy  a cmp =
  let l = length a in
  if l <= cutoff then insertionSort a 0 a 0 l cmp 
  else begin
    let l1 = l / 2 in
    let l2 = l - l1 in
    let t = Bs_Array.makeUninitializedUnsafe l2 in 
    sortTo a l1 t 0 l2 cmp;
    sortTo a 0 a l2 l1 cmp;
    merge a l2 l1 t 0 l2 a 0 cmp;
  end
let stableSortInts  (a : int array)  =
  let l = length a in
  if l <= cutoff then insertionSortInts a 0 a 0 l  
  else begin
    let l1 = l / 2 in
    let l2 = l - l1 in
    let t = Bs_Array.makeUninitializedUnsafe l2 in 
    sortToInts a l1 t 0 l2 ;
    sortToInts a 0 a l2 l1 ;
    mergeInts a l2 l1 t 0 l2 a 0 ;
  end
let stableSortFloats  (a : float array)  =
  let l = length a in
  if l <= cutoff then insertionSortFloats a 0 a 0 l  
  else begin
    let l1 = l / 2 in
    let l2 = l - l1 in
    let t = Bs_Array.makeUninitializedUnsafe l2 in 
    sortToFloats a l1 t 0 l2 ;
    sortToFloats a 0 a l2 l1 ;
    mergeFloats a l2 l1 t 0 l2 a 0 ;
  end


external sortBy : 
  'a array -> ('a -> 'a -> int [@bs]) -> unit = 
  "sort" [@@bs.send]

let sortByCont xs cmp = 
  sortBy xs cmp ; 
  xs   

(*
  [binSearchAux arr lo hi key cmp]
  range [lo, hi]
  input (lo <= hi)
  [arr[lo] <= key <= arr[hi]]

  If value is not found and value is less than one or more elements in array, 
  the negative number returned is the bitwise complement of the index of the first element 
  that is larger than value. 
  
  If value is not found and value is greater than all elements in array,
  the negative number returned is the bitwise complement of 
  (the index of the last element plus 1)

  for example, if [key] is smaller than all elements return [-1] since [lnot (-1) = 0]
  if [key] is largeer than all elements return [- (len + 1)] since (lnot (-(len+1)) = len]
*)  
let rec binSearchAux arr lo hi key cmp = 
  
    let mid = (lo + hi)/2 in 
    let midVal = A.unsafe_get arr mid in 
    let c = cmp key midVal [@bs] in 
    if c = 0 then mid 
    else if c < 0 then  (*  a[lo] =< key < a[mid] <= a[hi] *)
      if hi = mid then  
        if cmp (A.unsafe_get arr lo) key [@bs] = 0 then lo
        else - (hi + 1)
      else binSearchAux arr lo mid key cmp 
    else  (*  a[lo] =< a[mid] < key <= a[hi] *)
      if lo = mid then 
        if cmp (A.unsafe_get arr hi) key [@bs] = 0 then hi
        else - (hi + 1)
      else binSearchAux arr mid hi key cmp 

let binSearch sorted key cmp : int =  
  let len = A.length sorted in 
  if len = 0 then -1 
  else 
    let lo = A.unsafe_get sorted 0 in 
    let c = cmp key lo [@bs] in 
    if c < 0 then -1 
    else
    let hi = A.unsafe_get sorted (len - 1) in 
    let c2 = cmp key hi [@bs]in 
    if c2 > 0 then - (len + 1)
    else binSearchAux sorted 0 (len - 1) key cmp 