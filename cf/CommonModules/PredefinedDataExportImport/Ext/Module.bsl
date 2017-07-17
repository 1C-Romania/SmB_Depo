#Region ServiceProgramInterface

// Fills out the array of types for which you need to use the refs annotation in the export files when exporting.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingTypesRequireAnnotationRefsOnImport(Types) Export
	
	ObjectsWithPredefinedElements = PredefinedDataExportImportReUse.MetadataObjectsWithPredefinedElements();
	For Each TypeName IN ObjectsWithPredefinedElements Do
		
		If RequiredMatchingReferencesOnPredefinedElements(TypeName) Then
			Types.Add(Metadata.FindByFullName(TypeName));
		EndIf;
		
	EndDo;
	
EndProcedure

// It is called on the random handlers of export data registration.
//
// Parameters: HandlersTable - ValueTable, in
//  this procedure it is required to supplement this
//  table of values with information about registered random export data handlers. Columns:
//    MetadataObject - MetadataObject, when exporting
//      the data of which the registered handler must be called,
//    Handler - GeneralModule, a general module in
//      which random handler of the data export implemented. Set of export procedures
//      that must be implemented in the handler, depends on
//      the set values of the following table columns, 
//    Version - String - Interface version number of exporting/importing
//      data handlers, supported by handler, 
//    BeforeExportType - Boolean, a flag showing that a handler is to be called before exporting all the infobase objects that are associated with the metadata object. If the True value is set - in the general module
//      of a handler, exported procedure BeforeExportType() must be implemented, 
//      that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application processing interface DataExportImportContainerManager, 
//        Serializer - XDTOSerializator, initialized with
//          support the executing of the annotation refs. If a random exporting handler requires additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure BeforeExportType() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO, 
//        MetadataObject - MetadataObject before exporting
//          data of which the handler was called, 
//        Cancel - Boolean. If in the procedure
//          BeforeExportType() install this True parameter value - exporting
//          of objects matching the current metadata object will not be executed.
//    BeforeObjectExport - Boolean, a flag showing that it is required to call a handler before exporting a particular object of the infobase. If the
//      True value is set - in the general module of a handler, exported
//      procedure BeforeObjectExport() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application processing interface DataExportImportContainerManager, 
//        ExportObjectManager - ProcessingObject.DataExportImportInfobaseDataExportManager -
//          Manager of the current object export. See more the review to the
//          application processing interface  DataExportImportInfobaseDataExportManager.  
//          Parameter is passed only on the call of handler procedures for which at
//           registration specified  the version not below 1.0.0.1,
//        Serializer - XDTOSerializator, initialized with
//          support the executing of the annotation refs. If a random exporting handler requires additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure BeforeObjectExport() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO,
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before exporting of which the handler was called.
//          Value that is passed to the BeforeObjectExport() procedure as the Object parameter value can be modified within the BeforeObjectExport() processor, made changes will be shown in the object serialization of export files, but will not be recorded in the Artifacts infobase - Array(XDTOObject) - Set additional information logically
//          connected inextricably with the object but not not being his part artifacts object). Artifacts
//          should formed inside handler BeforeObjectExport() and added
//          to the array passed as parameter values Artifacts. Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem. Further
//          artifacts that are formed in the procedure BeforeObjectExport(), will
//          be available in handlers procedures of data import (see review for the procedure WhenDataImportHandlersRegistration().
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeObjectExport()- object export for which the
//           handler was called will not be executed.
//    AfterExportType() - Boolean, a flag showing that a handler is to be called after exporting all objects of the infobase that belongs to that metadata object. If the
//      True value is set - in a general module of the handler, exported procedure AfterExportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application processing interface DataExportImportContainerManager, 
//        Serializer - XDTOSerializator, initialized with
//          support the executing of the annotation refs. If a random exporting handler requires additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure AfterExportType() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO, 
//        MetadataObject - MetadataObject, after exporting
//          data of which the handler was called.
//
Procedure WhenDataImportHandlersRegistration(HandlersTable) Export
	
	ObjectsWithPredefinedElements = PredefinedDataExportImportReUse.MetadataObjectsWithPredefinedElements();
	For Each MetadataObjectName IN ObjectsWithPredefinedElements Do
		
		If RequiredMatchingReferencesOnPredefinedElements(MetadataObjectName) Then
			
			NewHandler = HandlersTable.Add();
			NewHandler.MetadataObject = Metadata.FindByFullName(MetadataObjectName);
			NewHandler.Handler = PredefinedDataExportImport;
			NewHandler.AfterObjectExport = True;
			NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure AfterObjectExport(Container, ObjectExportManager, Serializer, Object, Artifacts) Export
	
	If CommonUseSTL.IsReferenceDataSupportPredefinedItems(Object.Metadata()) Then
		
		If RequiredMatchingReferencesOnPredefinedElements(Object.Metadata().FullName()) Then
			
			If Object.Predefined Then
				
				If CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_3() Then
					NaturalKey = New Structure("PredefinedDataName", Object.PredefinedDataName);
				Else
					ObjectManager = CommonUse.ObjectManagerByFullName(Object.Metadata().FullName());
					NaturalKey = New Structure("PredefinedDataName", ObjectManager.GetPredefinedItemName(Object.Ref));
				EndIf;
				
				ObjectExportManager.RequireMatchRefOnImport(Object.Ref, NaturalKey);
				
			EndIf;
			
		Else
			
			Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en='The %1 metadata object  
		|can not be processed by the 
		|PredefinedDataExportImport.BeforeObjectExport() handler
		|as it is not required to ensure mapping of references to its predefined items!';ru='Объект метаданных %1 не может быть обработан обработчиком
		|ВыгрузкаЗагрузкаПредопределенныхДанных.ПередВыгрузкойОбъекта(),
		|т.к. не требуется обеспечивать сопоставление ссылок на его предопределенные элементы!'", Metadata.DefaultLanguage.LanguageCode),
			Object.Metadata().FullName()
		);
			
		EndIf;
		
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en='The %1 metadata object  
		|can not be processed by the PredefinedDataExportImport.BeforeObjectExport() handler,
		|as it can not contain predefined items!';ru='Объект метаданных %1 не может быть обработан обработчиком
		|ВыгрузкаЗагрузкаПредопределенныхДанных.ПередВыгрузкойОбъекта(),
		|т.к. не может содержать предопределенных элементов!'", Metadata.DefaultLanguage.LanguageCode),
			Object.Metadata().FullName()
		);
		
	EndIf;
	
EndProcedure

Procedure BeforeCleaningData(Container) Export
	
	If CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_5() Then
		
		SetPredefinedDataInitializationCurrentDataAreas(Container.ExportParameters().ImportedTypes);
		
	ElsIf CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_3() Then
		
		WorkInSafeMode.ExecuteInSafeMode("InitializePredefinedData();");
		
	EndIf;
	
EndProcedure

Procedure WhenDataExportHandlersRegistration(HandlersTable) Export
	
	NewHandler = HandlersTable.Add();
	NewHandler.Handler = PredefinedDataExportImport;
	NewHandler.BeforeCleaningData = True;
	NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
	
	ObjectsWithPredefinedElements = PredefinedDataExportImportReUse.MetadataObjectsWithPredefinedElements();
	For Each MetadataObjectName IN ObjectsWithPredefinedElements Do
		
		If RequiredMatchingReferencesOnPredefinedElements(MetadataObjectName) Then
			
			NewHandler = HandlersTable.Add();
			NewHandler.MetadataObject = Metadata.FindByFullName(MetadataObjectName);
			NewHandler.Handler = PredefinedDataExportImport;
			NewHandler.BeforeMatchRefs = True;
			NewHandler.BeforeObjectImport = True;
			NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure BeforeMatchRefs(Container, MetadataObject, SourceRefsTable, StandardProcessing, Cancel) Export
	
	If CommonUseSTL.IsReferenceDataSupportPredefinedItems(MetadataObject)
			AND SourceRefsTable.Columns.Find("PredefinedDataName") <> Undefined Then
		
		If Not CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_3() Then
			// Until platform version 8.3.3 for predefined elements the
			// same link is always used and execute the matching of refs to them is not required
			Cancel = True;
		Else
			StandardProcessing = False
		EndIf;
		
	EndIf;
	
EndProcedure

Function MatchRefs(Container, RefsMappingManager, SourceRefsTable) Export
	
	SourceRefsForStandardProcessing = New ValueTable();
	For Each Column IN SourceRefsTable.Columns Do
		If Column.Name <> "PredefinedDataName" Then
			SourceRefsForStandardProcessing.Columns.Add(Column.Name, Column.ValueType);
		EndIf;
	EndDo;
	
	ColumnName = RefsMappingManager.SourceRefsColumnName();
	
	Result = New ValueTable();
	Result.Columns.Add(ColumnName, SourceRefsTable.Columns.Find(ColumnName).ValueType);
	Result.Columns.Add("Ref", SourceRefsTable.Columns.Find(ColumnName).ValueType);
	
	MetadataObject = Undefined;
	
	For Each TableRowSourceLinks IN SourceRefsTable Do
		
		If ValueIsFilled(TableRowSourceLinks.PredefinedDataName) Then
			
			QueryText = 
				"SELECT
				|	Table.Ref AS Ref
				|FROM
				|	" + TableRowSourceLinks[ColumnName].Metadata().FullName() + " As
				|Table
				|	WHERE Table.PredefinedDataName = &PredefinedDataName";
			Query = New Query(QueryText);
			Query.SetParameter("PredefinedDataName", TableRowSourceLinks.PredefinedDataName);
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				
				Selection = QueryResult.Select();
				
				If Selection.Count() = 1 Then
					
					Selection.Next();
					
					ResultRow = Result.Add();
					ResultRow.Ref = Selection.Ref;
					ResultRow[ColumnName] = TableRowSourceLinks[ColumnName];
					
				Else
					
					Raise StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='Duplication of predefined items %1 is detected in table %2.';ru='Обнаружено дублирование предопределенных элементов %1 в таблице %2!'", Metadata.DefaultLanguage.LanguageCode),
						TableRowSourceLinks.PredefinedDataName,
						TableRowSourceLinks[ColumnName].Metadata().FullName()
					);
					
				EndIf;
				
			EndIf;
			
		Else
			
			If MetadataObject = Undefined Then
				MetadataObject = TableRowSourceLinks[ColumnName].Metadata();
			EndIf;
			
			RefsForStandardProcessing = SourceRefsForStandardProcessing.Add();
			FillPropertyValues(RefsForStandardProcessing, TableRowSourceLinks);
			
		EndIf;
		
	EndDo;
	
	If SourceRefsForStandardProcessing.Count() > 0 Then
		
		Selection = DataProcessors.DataExportImportRefsMappingManager.MatchRefsSelection(
			MetadataObject, SourceRefsForStandardProcessing, ColumnName);
		
		While Selection.Next() Do
			
			ResultRow = Result.Add();
			ResultRow.Ref = Selection.Ref;
			ResultRow[ColumnName] = Selection[ColumnName];
			
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure BeforeObjectImport(Container, Object, Artifacts, Cancel) Export
	
	MetadataObject = Object.Metadata();
	
	If CommonUseSTL.IsReferenceDataSupportPredefinedItems(MetadataObject) Then
		
		If Not CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_3() AND Object.Predefined AND Object.DeletionMark Then
			
			// Until platform version 8.3.3 marked for deletion predefined elements are not allowed
			Object.DeletionMark = False;
			
		EndIf;
		
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en='The %1 metadata object  
		|can not be processed by the PredefinedDataExportImport.BeforeObjectExport() handler,
		|as it can not contain predefined items!';ru='Объект метаданных %1 не может быть обработан обработчиком
		|ВыгрузкаЗагрузкаПредопределенныхДанных.ПередВыгрузкойОбъекта(),
		|т.к. не может содержать предопределенных элементов!'", Metadata.DefaultLanguage.LanguageCode),
			Object.Metadata().FullName()
		);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure SetPredefinedDataInitializationCurrentDataAreas(MetadataObjects)
	
	For Each MetadataObject IN MetadataObjects Do
		
		If CommonUseSTL.IsReferenceDataSupportPredefinedItems(MetadataObject) Then
			
			If MetadataObject.GetPredefinedNames().Count() > 0 Then
				
				Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
				Manager.SetPredefinedDataInitialization(True);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function RequiredMatchingReferencesOnPredefinedElements(TypeName)
	
	If Not CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_3() Then
		
		Return False;
		
	EndIf;
	
	If CommonUseReUse.IsSeparatedMetadataObject(TypeName, SaaSOperations.MainDataSeparator())
		OR CommonUseReUse.IsSeparatedMetadataObject(TypeName, SaaSOperations.SupportDataSplitter()) Then
		
		If CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_5() Then
			
			Return False;
			
		Else
			
			Return True;
			
		EndIf;
		
	Else
		
		// For undivided objects the mapping of references to the predefined items is always required
		Return True;
		
	EndIf;
	
EndFunction

#EndRegion