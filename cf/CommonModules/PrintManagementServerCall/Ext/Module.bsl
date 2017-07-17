////////////////////////////////////////////////////////////////////////////////
// Subsystem "Print".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Work with office documents templates.

// Gets in one call all necessary information for printing: templates data items,
// binary data template, description of templates areas.
// For calling the print forms from client modules according to office document templates.
//
// Parameters:
//   PrintManagerName    - String - name for referring to the object manager, for example "Document.<Document name>".
//   TemplateNames       - String - template names that will form print forms.
//   ContentOfDocuments  - Array  - references to the infobase objects (must be of the same type).
//
Function TemplatesAndDataObjectsForPrinting(Val PrintManagerName, Val TemplateNames, Val ContentOfDocuments) Export
	
	Return PrintManagement.TemplatesAndDataObjectsForPrinting(PrintManagerName, TemplateNames, ContentOfDocuments);
	
EndFunction

// Outdated. You should use TemplatesAndDataObjectsForPrinting.
//
Function GetTemplatesAndDataOfObjects(Val PrintManagerName, Val TemplateNames, Val ContentOfDocuments) Export
	
	Return PrintManagement.TemplatesAndDataObjectsForPrinting(PrintManagerName, TemplateNames, ContentOfDocuments);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Generate print forms for output directly to a printer.
//
// Details - see the description of PrintManagment.FormPrintingFormForQuickPrint().
//
Function GeneratePrintFormsForQuickPrint(PrintManagerName, TemplateNames, ObjectsArray,	PrintParameters) Export
	
	Return PrintManagement.GeneratePrintFormsForQuickPrint(PrintManagerName, TemplateNames,
		ObjectsArray,	PrintParameters);
	
EndFunction

// Generate print forms for direct output to a printer in a basic application.
//
// Details - see description of the PrintManagment.FormPrintingFormForQuickPrintBasicApplication().
//
Function GeneratePrintFormsForQuickPrintOrdinaryApplication(PrintManagerName, TemplateNames, ObjectsArray, PrintParameters) Export
	
	Return PrintManagement.GeneratePrintFormsForQuickPrintOrdinaryApplication(PrintManagerName, TemplateNames,
		ObjectsArray,	PrintParameters);
	
EndFunction

// Saves in temporary storage path to directory which is used for printing.
//
// Details - see the description of PrintManagment.SaveLocalDirectoryOfPrintFiles().
//
Procedure SaveLocalDirectoryOfPrintFiles(Directory) Export
	
	PrintManagement.SaveLocalDirectoryOfPrintFiles(Directory);
	
EndProcedure

// Returns the command description according to the name of the form.
// 
// See PrintManagement.PrintCommandDetails
//
Function DetailsPrintCommands(CommandName, AddressPrintingCommandsInTemporaryStorage) Export
	
	Return PrintManagement.DetailsPrintCommands(CommandName, AddressPrintingCommandsInTemporaryStorage);
	
EndFunction

// Returns true if there is a permission to post at least one document.
Function PostingRightAvailable(DocumentsList) Export
	Return PrintManagement.PostingRightAvailable(DocumentsList);
EndFunction

// See PrintManagement.DocumentsPackage.
Function DocumentsPackage(DocumentsTable, PrintObjects, PrintInSets, Copies = 1) Export
	
	Return PrintManagement.DocumentsPackage(DocumentsTable, PrintObjects,
		PrintInSets, Copies);
	
EndFunction

// Command print unavailability message for the selected object.
Function MessageAboutPrintingCommandPurpose(PrintingObjectsTypes) Export
	MessageText = NStr("en='The selected print command is intended for documents';ru='Выбранная команда печати предназначена для документов'") 
		+ ?(PrintingObjectsTypes.Count() = 1, " ", ": " + Chars.LF);
	For Each Type IN PrintingObjectsTypes Do
		MessageText = MessageText + Metadata.FindByType(Type).ListPresentation + Chars.LF;
	EndDo;
	Return TrimAll(MessageText);
EndFunction

Function NewPrintedFormsCollection(IDs) Export
	Return CommonUse.ValueTableToArray(PrintManagement.PrepareCollectionOfPrintForms(IDs));
EndFunction

#EndRegion
