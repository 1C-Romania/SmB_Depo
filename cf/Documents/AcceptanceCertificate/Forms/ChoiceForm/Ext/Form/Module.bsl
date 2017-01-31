
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - Form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure OnOpen(Cancel)
	
	//( elmi # 08.5 
	SmallBusinessClient.RenameTitleExchangeRateMultiplicity( ThisForm, "List");
    //) elmi

	
	
EndProcedure
