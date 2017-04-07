////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AttachedFiles.CallFormOpeningException(ThisForm);
	
EndProcedure
