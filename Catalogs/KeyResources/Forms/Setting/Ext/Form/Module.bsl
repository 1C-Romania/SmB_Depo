
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure fills form attributes from parameters.
//
&AtServer
Procedure FillAttributesByParameters()
	
	If Parameters.Property("RepetitionFactorOFDay") Then
		RepetitionFactorOFDay = Parameters.RepetitionFactorOFDay;
		RepetitionFactorOFDayOnOpen = Parameters.RepetitionFactorOFDay;
	EndIf;
	
EndProcedure // CheckIfFormWasModified()

// Procedure checks if the form was modified.
//
&AtClient
Procedure CheckIfFormWasModified()
	
	WereMadeChanges = False;
	
	ChangesRepetitionFactorOFDay = RepetitionFactorOFDayOnOpen <> RepetitionFactorOFDay;
	
	If ChangesRepetitionFactorOFDay Then
		WereMadeChanges = True;
	EndIf;
	
EndProcedure // CheckIfFormWasModified()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillAttributesByParameters();
	
	WereMadeChanges = False;
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - event handler of clicking the OK button.
//
&AtClient
Procedure CommandOK(Command)
	
	CheckIfFormWasModified();
	
	StructureOfFormAttributes = New Structure;
	
	StructureOfFormAttributes.Insert("WereMadeChanges", WereMadeChanges);
	
	StructureOfFormAttributes.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	
	Close(StructureOfFormAttributes);
	
EndProcedure // CommandOK()