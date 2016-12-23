////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonUseClientServer.SetFilterDynamicListItem(List, "EDAgreement", Parameters.EDAgreement);
	
EndProcedure














