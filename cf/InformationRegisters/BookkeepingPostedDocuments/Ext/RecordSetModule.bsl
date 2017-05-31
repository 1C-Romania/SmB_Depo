Var mProgramBookkeepingPostingFlag;

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENTS PROCESSING OF THE OBJECT


Procedure BeforeWrite(Cancel, Replacing)
	
	If NOT mProgramBookkeepingPostingFlag Then
		
		Cancel = True;	
		
	EndIf;	

	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OTHER PROCEDURES


Procedure SetProgramBookkeepingPostingFlag() Export
	
	mProgramBookkeepingPostingFlag = True;	
	
EndProcedure	

mProgramBookkeepingPostingFlag = False;