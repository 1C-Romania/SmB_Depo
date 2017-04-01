#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Exports the info base data.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//
Procedure ExportInfobaseData(Container, Handlers, Serializer) Export
	
	ExportedTypes = Container.ExportParameters().ExportedTypes;
	ExcludedTypes = DataExportImportServiceEvents.GetTypesExcludedFromExportImport();
	
	CurrentRecreatedRefsWriteStream = DataProcessors.DataExportImportRecreatedLinksWritingStream.Create();
	CurrentRecreatedRefsWriteStream.Initialize(Container, Serializer);
	
	CurrentMappedRefsWriteStream = DataProcessors.DataExportImportMappedLinksWritingStream.Create();
	CurrentMappedRefsWriteStream.Initialize(Container, Serializer);
	
	For Each MetadataObject IN ExportedTypes Do
		
		If ExcludedTypes.Find(MetadataObject) <> Undefined Then
			
			WriteLogEvent(
				NStr("en='DataExportImport.ObjectExportSkipped';ru='ВыгрузкаЗагрузкаДанных.ЗагрузкаОбъектаПропущена'", Metadata.DefaultLanguage.LanguageCode),
				EventLogLevel.Information,
				MetadataObject,
				,
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Export of metadata object %1 is skipped as it is
		|included in the metadata object list excluded from data export and import';ru='Выгрузка данных объекта метаданных %1 пропущена, т.к. он включен в
		|список объектов метаданных, исключаемых из выгрузки и загрузки данных'", Metadata.DefaultLanguage.LanguageCode),
					MetadataObject.FullName()
				)
			);
			
			Continue;
			
		EndIf;
		
		ObjectExportManager = Create();
		
		ObjectExportManager.Initialize(
			Container,
			MetadataObject,
			Handlers,
			Serializer,
			CurrentRecreatedRefsWriteStream,
			CurrentMappedRefsWriteStream);
		
		ObjectExportManager.ExportData();
		
		ObjectExportManager.Close();
		
	EndDo;
	
	CurrentRecreatedRefsWriteStream.Close();
	CurrentMappedRefsWriteStream.Close();
	
EndProcedure

#EndRegion

#EndIf
