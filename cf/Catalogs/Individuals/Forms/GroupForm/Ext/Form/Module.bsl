////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_Individuals", WriteParameters, Object.Ref);
	
EndProcedure
