////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AttachedFiles.OnCreateAtServerAttachedFile(ThisForm);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure Attachable_GoToFileForm(Command)
	
	AttachedFilesClient.GoToAttachedFileForm(ThisForm);
	
EndProcedure














