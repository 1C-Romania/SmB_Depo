#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalState

Var CurrentContainer;
Var CurrentImportedTypes;
Var CurrentExcludedTypes;
Var CurrentHandlers;

#EndRegion

#Region ServiceProgramInterface

Procedure Initialize(Container, ImportedTypes, ExcludedTypes, Handlers) Export
	
	CurrentContainer = Container;
	CurrentImportedTypes = ImportedTypes;
	CurrentImportedTypes = SortImportedTypes(CurrentImportedTypes);
	CurrentExcludedTypes = ExcludedTypes;
	CurrentHandlers = Handlers;
	
EndProcedure

Procedure ImportData() Export
	
	ReplaceRefs();
	ExecuteDataImport();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

//Types are sorted from top to low priority, serializers are selected from the array from the end.
//
// Parameters:
// ImportedTypes - Array - metadata array.
//
// Returns:
// Array - sorted metadata array by priority.
//
Function SortImportedTypes(Val ImportedTypes)
	
	Sort = New ValueTable();
	Sort.Columns.Add("MetadataObject");
	Sort.Columns.Add("Priority", New TypeDescription("Number"));
	
	For Each MetadataObject IN ImportedTypes Do
		
		String = Sort.Add();
		String.MetadataObject = MetadataObject;
		
		If CommonUseSTL.ThisIsConstant(MetadataObject) Then
			String.Priority = 0;
		ElsIf CommonUseSTL.ThisIsReferenceData(MetadataObject) Then
			String.Priority = 1;
		ElsIf CommonUseSTL.ThisIsRecordSet(MetadataObject) Then
			String.Priority = 2;
		ElsIf Metadata.CalculationRegisters.Contains(MetadataObject.Parent()) Then // Recalculations
			String.Priority = 3;
		ElsIf Metadata.Sequences.Contains(MetadataObject) Then
			String.Priority = 4;
		Else
			TextPattern = NStr("en='Metadata object export is not supported %1';ru='Выгрузка объекта метаданных не поддерживается %1'");
			MessageText = ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(TextPattern, MetadataObject.FullName());
			Raise(MessageText);
		EndIf;
		
	EndDo;
	
	Sort.Sort("Priority");
	
	Return Sort.UnloadColumn("MetadataObject");
	
EndFunction

Procedure ReplaceRefs()
	
	RefReplacementStream = DataProcessors.DataExportImportLinkReplacementStream.Create();
	RefReplacementStream.Initialize(CurrentContainer, CurrentHandlers);
	
	RefsRecreationManager = DataProcessors.DataExportImportLinkRecreationManager.Create();
	RefsRecreationManager.Initialize(CurrentContainer, RefReplacementStream);
	RefsRecreationManager.RecreateRefs();
	
	RefsMappingManager = DataProcessors.DataExportImportRefsMappingManager.Create();
	RefsMappingManager.Initialize(CurrentContainer, RefReplacementStream, CurrentHandlers);
	RefsMappingManager.MapRefs();
	
	RefReplacementStream.Close();
	
EndProcedure

Procedure ExecuteDataImport()
	
	For Each MetadataObject IN CurrentImportedTypes Do
		
		If CurrentExcludedTypes.Find(MetadataObject) = Undefined Then
			
			Cancel = False;
			CurrentHandlers.BeforeImportType(CurrentContainer, MetadataObject, Cancel);
			
			If Not Cancel Then
				ImportInfobaseObjectData(MetadataObject);
			EndIf;
			
			CurrentHandlers.AfterImportType(CurrentContainer, MetadataObject);
			
		Else
			
			WriteLogEvent(
				NStr("en='DataExportImport.ObjectExportSkipped';ru='ВыгрузкаЗагрузкаДанных.ЗагрузкаОбъектаПропущена'", Metadata.DefaultLanguage.LanguageCode),
				EventLogLevel.Information,
				MetadataObject,
				,
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Import of metadata object %1 data is skipped as it is
		|included in the metadata object list excluded from data export and import';ru='Выгрузка данных объекта метаданных %1 пропущена, т.к. он включен в
		|список объектов метаданных, исключаемых из выгрузки и загрузки данных'", Metadata.DefaultLanguage.LanguageCode),
					MetadataObject.FullName()
				)
			);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports all required data for the info base object.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// MetadataObject - metadata object that is being imported.
// Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
//
Procedure ImportInfobaseObjectData(Val MetadataObject)
	
	FileName = CurrentContainer.GetFileFromDirectory(DataExportImportService.InfobaseData(), MetadataObject.FullName());
	If FileName = Undefined Then 
		Return;
	EndIf;
	
	ReadStream = DataProcessors.DataExportImportInfobaseDataReadingStream.Create();
	ReadStream.OpenFile(FileName);
	
	While ReadStream.ReadInfobaseDataObject() Do
		
		Object = ReadStream.CurrentObject();
		Artifacts = ReadStream.CurrentObjectArtifacts();
		
		WriteObjectToInfobase(Object, Artifacts);
		
	EndDo;
	
EndProcedure

// Writes an object into the infobase.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// Object - metadata object that is being imported.
// ObjectArtifacts - Array - XDTO objects array.
// Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure WriteObjectToInfobase(Object, ObjectArtifacts)
	
	Cancel = False;
	CurrentHandlers.BeforeObjectImport(CurrentContainer, Object, ObjectArtifacts, Cancel);
	
	If Not Cancel Then
		
		If CommonUseSTL.ThisIsConstant(Object.Metadata()) Then
			
			If Not ValueIsFilled(Object.Value) Then
				// As the constants were cleared before - it is
				// not required to rewrite empty values
				Return;
			EndIf;
			
		EndIf;
		
		Object.DataExchange.Load = True;
		
		If CommonUseSTL.IsIndependentRecordSet(Object.Metadata()) Then
			
			// Because independent record sets are exported by cursor queries - writes
			// without replacement
			Object.Write(False);
			
		Else
			
			Object.Write();
			
		EndIf;
		
	EndIf;
	
	CurrentHandlers.AftertObjectImport(CurrentContainer, Object, ObjectArtifacts);
	
EndProcedure

#EndRegion

#EndIf
