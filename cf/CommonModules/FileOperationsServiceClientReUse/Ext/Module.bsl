////////////////////////////////////////////////////////////////////////////////
// Subsystem "Working with files".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns a form which is used when creating a new file
// for selection of the creation option.
Function NewFileCreatingOptionChoiceForm() Export
	
	CommandScanAvailable = FileOperationsServiceClient.CommandScanAvailable();
	FormParameters = New Structure("CommandScanAvailable", CommandScanAvailable);
	Return GetForm("Catalog.Files.Form.FormOfNew", FormParameters);
	
EndFunction

// Returns a form which is used to inform users about files return features in web client.
Function ReminderFormBeforePlacingFile() Export
	Return GetForm("Catalog.Files.Form.ReminderFormBeforePlacingFile");
EndFunction

// Returns a form which is used when returning the edited file to server.
Function FileReturnForm() Export
	Return GetForm("Catalog.Files.Form.FileReturnForm");
EndFunction

// Returns a form which is used to enter the saving mode when exporting a folder,
// if there is a file already with the same name on the disk.
Function FolderExportFormFileExists() Export
	Return GetForm("Catalog.Files.Form.FileExists");
EndFunction

#EndRegion
