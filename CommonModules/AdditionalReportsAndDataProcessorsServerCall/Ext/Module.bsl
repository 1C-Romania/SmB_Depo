////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and data processors".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Connects an external data processor (report).
//   Details - see AdditionalReportsAndDataProcessors.ConnectExternalDataProcessor().
//
Function ConnectExternalDataProcessor(Refs) Export
	
	Return AdditionalReportsAndDataProcessors.ConnectExternalDataProcessor(Refs);
	
EndFunction

// Creates and returns a sample of the external data processor (report).
//   Details - see AdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor().
//
Function GetObjectOfExternalDataProcessor(Refs) Export
	
	Return AdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor(Refs);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Runs the data processor command and places the result into temporary storage.
//   Details - see AdditionalReportsAndDataProcessors.RunCommand().
//
Function RunCommand(CommandParameters, ResultAddress = Undefined) Export
	
	Return AdditionalReportsAndDataProcessors.RunCommand(CommandParameters, ResultAddress);
	
EndFunction

// Places binary data of additional report or data processor into temporary storage.
Function PlaceIntoStorage(Refs, FormID) Export
	If TypeOf(Refs) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") 
		Or Refs = Catalogs.AdditionalReportsAndDataProcessors.EmptyRef() Then
		Return Undefined;
	EndIf;
	If Not AdditionalReportsAndDataProcessors.DataProcessorExportToFileIsAvailable(Refs) Then
		Raise NStr("en='Insufficient rights for exporting the files of additional reports and data processors';ru='Недостаточно прав для выгрузки файлов дополнительных отчетов и обработок'");
	EndIf;
	
	DataProcessorStorage = CommonUse.ObjectAttributeValue(Refs, "DataProcessorStorage");
	
	Return PutToTempStorage(DataProcessorStorage.Get(), FormID);
EndFunction

Function DataProcessorCommandsDescription(ItemName, CommandsInTemporaryStorageTableAddress) Export
	Return AdditionalReportsAndDataProcessors.DataProcessorCommandsDescription(ItemName, CommandsInTemporaryStorageTableAddress);
EndFunction

#EndRegion
