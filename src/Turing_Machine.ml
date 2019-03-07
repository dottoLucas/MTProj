(* Micha�l P�RIN, Verimag / Universit� Grenoble-Alpes, F�vrier 2017
 *
 * Part of the project TURING MACHINES FOR REAL
 *
 * CONTENT 
 *
 *  - Turing Machines
 *  - Transitions of Turing Machines
 *  - Intruction  of Transition of Turing Machines
 *  
 *
 * USAGE
 *
 *   Requirement
 *   - Module   :  MyList.cmo MyString.cmo Tricks.cmo Pretty.cmo Color.cmo Html.cmo Symbol.cmo Bit_Vector.cmo Alphabet.cmo Pattern.cmo Band.cmo Action.cmo State.cmo Band.cmo
 *   - Library  :  
 *   Compilation:  ocamlc      MyList.cmo MyString.cmo Tricks.cmo Pretty.cmo Color.cmo Html.cmo Symbol.cmo Bit_Vector.cmo Alphabet.cmo Pattern.cmo Band.cmo Action.cmo State.cmo Band.cmo Turing_Machine.ml
 *   Interpreter:  ledit ocaml MyList.cmo MyString.cmo Tricks.cmo Pretty.cmo Color.cmo Html.cmo Symbol.cmo Bit_Vector.cmo Alphabet.cmo Pattern.cmo Band.cmo Action.cmo State.cmo Band.cmo Turing_Machine.cmo 
 *
 *)

 
open Symbol
open Alphabet
open Band   

open State
open Pattern
open Action

open Html
open Pretty


   
(** Types *)  
  
type transition = State.t * instruction * State.t

and instruction =
  | Action of Action.t
  | Seq  of instruction list (* a sequence of instructions *)

  | Run_on of turing_machine * Band.indexes (* Run_on(Turing Machine, indexes of bands) *)

  | Parallel of instruction list (* N one-band instructions in paralell on N bands *)

  (* DEPRECATED *)             
  | Run  of turing_machine (* DEPRECATED *)
  | Call of string (* DEPRECATED: the name of an existing turing machine *)


and transitions = transition list
  
and turing_machine = { name        : string ;
		       nb_bands    : int ;
		       initial     : State.t ;
                       accept      : State.t ;
                       reject      : State.t ;
		       transitions : transitions ;
		     }

                   
(** INSTRUCTION *)
                   
module Instruction =
  (struct
    type t = instruction

    let (nop: instruction) = Seq []
	
    let (zip: instruction list -> Band.t list -> (instruction * Band.t) list) =  Band.zip_complete_with nop 


    (* ENABLED ONE INSTRUCTION on ONE BAND *)
                                                                                                             
    let rec (is_enabled_on_this: Band.t -> instruction -> bool) = fun band instruction ->
      match instruction with
      | Action action -> Action.is_enabled_on_this band action
      | Call _ | Run  _ -> true
      | Seq [] -> false (* FIXME SEMANTICS: false? or true?: is there a risk of looping by stuttering? *)
      | Seq (first_instruction::_) -> is_enabled_on_this band first_instruction


    (* ENABLED COMPLEX INSTRUCTION on MULTIPLE BANDS *)
                                                                                                             
    let rec (is_enabled_on: Band.t list -> instruction -> bool) = fun bands instruction ->
      (bands <> [])
      &&
	(match instruction with
	 | Action action -> Action.is_enabled_on bands action
		          
	 | Call _  | Run  _ -> true

         | Seq [] -> false 
	 | Seq (first_instruction::_) -> is_enabled_on bands first_instruction
		                       
	 | Parallel instructions ->
	    List.for_all
	      (fun (instruction,band) -> is_enabled_on_this band instruction)
	      (zip instructions bands)
	)

	
    (* PRETTY PRINTING *)
	
    let rec (to_ascii: t -> string) = fun instruction ->
	  match instruction with
	  | Action action -> Action.to_ascii action
	  | Call tm_name -> tm_name
	  | Run tm -> tm.name
	  | Seq instructions -> Pretty.brace (String.concat " ; " (List.map to_ascii instructions))
	  | Parallel instructions -> Pretty.bracket (String.concat " || " (List.map to_ascii instructions))
		    
    let (to_html: Html.options -> instruction -> Html.cell) = fun options instruction ->
	  Html.cell options (to_ascii instruction)
	    
    (* user *)

    let (pretty: t -> string) = fun t ->
	  match Pretty.get_format() with
	  | Pretty.Html  -> to_html [] t
	  | Pretty.Ascii -> to_ascii t
		  
  end)


  
(** TRANSITION *)
    
module Transition =
  (struct

    type t = transition
	  
    let (nop: State.t -> State.t -> transition) = fun source target ->  (source, Action(Nop), target)


    (* INSTANCIATON of generic transitions (PROJECT 2015) *)
		    
    let (foreach_symbol_of: 'a list -> 'a Pattern.t -> ('a -> transitions) -> transitions) = fun alphabet pattern create_transitions_for ->
	  let rec
	      (instantiate_transitions_foreach_symbol_in: 'a list -> transitions) = fun symbols  ->
		    match symbols with
		    | [] -> []
		    | s::ymbols ->
			    MyList.union
			      (create_transitions_for s)
			      (instantiate_transitions_foreach_symbol_in ymbols)
	  in
	    instantiate_transitions_foreach_symbol_in (Pattern.enumerate_symbols_of alphabet pattern)

	      
   (* PRETTY PRINTING *)

    let (to_ascii: t -> string) = fun (source,instruction,target) ->
	  String.concat " " [ State.to_ascii source ; "--" ; Instruction.to_ascii instruction ; "->" ; State.to_ascii target ]

	    
    let (to_ascii_many: t list -> string) = fun transitions ->
      transitions
      |> (List.map to_ascii)
      |> (String.concat ";")

    (* user *)

    let (pretty: t -> string) = fun t ->
	  match Pretty.get_format() with
	  | Pretty.Html  
	  | Pretty.Ascii -> to_ascii t

  end)
    


(** TURING MACHINES *)

  
module Turing_Machine =
  (struct
    
    type t = turing_machine 
	   
    let (nop: t) = { name = "" ;
		     nb_bands = 1 ; 
                     (* active_bands = [1] ; *)
		     initial = State.initial ;
                     accept  = State.accept  ;
                     reject  = State.reject  ;
		     transitions = [ (State.initial, Action(Nop), State.accept) ]
		   }

    let naming: string -> turing_machine -> turing_machine = fun name tm ->
      { tm with name = name }

    let sequence: Instruction.t list -> turing_machine = fun instructions ->
      let init = nop.initial and accept = nop.accept in
      { nop with
	name = Instruction.to_ascii (Seq instructions) ;
	transitions = [ (init, Seq instructions, accept) ]	    
      }

    (* PRETTY PRINTING *)

    let to_ascii: turing_machine -> string = fun tm -> tm.name

    let to_html: Html.options -> turing_machine -> Html.content = fun _ tm -> Html.italic (to_ascii tm)
	    
    (* user *)
	    
    let pretty (* user *) : t -> string =
      match Pretty.get_format() with
      | Pretty.Html  -> (to_html [])
      | Pretty.Ascii -> to_ascii
   (* | Pretty.Dot   -> TODO *)
		
		
    (* IMPERATIVE FEATURES for reusing existing turing machine *) 	    
		
    class collection_of_turing_machine =
    object
      val mutable collection: turing_machine list = []
	    
      method add: turing_machine -> unit = fun tm ->
	      collection <- tm::collection 
				  
      method find: string -> turing_machine = fun name ->
	match List.filter (fun tm -> tm.name = name) collection with
	| [tm] -> tm
	| [] -> let error_msg = String.concat "" [ "Turing_Machine.collection_of_turing_machine #find: TM " ; name ; " not found in the library." ] in failwith error_msg
	| _  -> let error_msg = String.concat "" [ "Turing_Machine.collection_of_turing_machine #find: Multiple TM " ; name ; " in the library."  ] in failwith error_msg
    end
	
	
    let global_TM_library = new collection_of_turing_machine

    (* FIXME i_store is a better name *)
	                  
    let i_store: string -> turing_machine -> turing_machine = fun name turing_machine ->
      let tm = naming name turing_machine in
      begin
	global_TM_library#add tm ;
	tm
      end
	      
    let i_find_tm_named: string -> turing_machine = fun name ->
      global_TM_library#find name
	    
  end)


