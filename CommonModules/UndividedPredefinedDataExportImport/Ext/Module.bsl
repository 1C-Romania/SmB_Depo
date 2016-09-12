// It is called on the registration of the arbitrary handlers of data export.
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
//      of a handler, exported procedure
//      BeforeExportType() must be implemented, that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager, 
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure BeforeExportType() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO,
//        MetadataObject - MetadataObject before exporting
//          data of which the handler was called, 
//        Cancel - Boolean. If in the procedure
//          BeforeExportType() install this True parameter value - exporting
//          of objects corresponding to the current metadata object will not be executed.
//    BeforeObjectExport - Boolean, a flag showing that it is required to call a handler before exporting a particular object of the infobase. If the
//      True value is set - in the general module of a handler, exported
//      procedure BeforeObjectExport() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager, 
//        ExportObjectManager - DataProcessorObject.DataExportImportInfobaseDataExportManager -
//          Manager of the current object export. See more the review to the
//          application data processor interface DataExportImportInfobaseDataExportManager. 
//          Parameter is passed only
//          on the call of handler procedures for which at registration specified  the version not below 1.0.0.1, 
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure BeforeObjectExport() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO, 
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before exporting of which the handler was called.
//          Value that is passed to the BeforeObjectExport() procedure as the Object parameter value can be modified within the BeforeObjectExport() processor, made changes will be shown in the object serialization of export files, but will not be recorded in the infobase 
//        Artifacts - Array(XDTOObject) - Set additional information logically
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
//          the review to the application data processor interface DataExportImportContainerManager,
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure AfterExportType() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO,
//         MetadataObject - MetadataObject, after exporting
//          data of which the handler was called.
//
Procedure WhenDataImportHandlersRegistration(HandlersTable) Export
	
	NewHandler = HandlersTable.Add();
	NewHandler.Handler = UndividedPredefinedDataExportImport;
	NewHandler.BeforeDataExport = True;
	NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
	
EndProcedure

Procedure BeforeDataExport(Container) Export
	
	ExportParameters = New Structure(Container.ExportParameters());
	
	AdditionallyExported = New Array();
	
	ControlRules = ExportImportUndividedDataReUse.ControlReferencesToUndividedDataInSeparatedOnExport();
	
	For Each ControlRule IN ControlRules Do
		
		MetadataObject = Metadata.FindByFullName(ControlRule.Key);
		
		If ExportParameters.ExportedTypes.Find(MetadataObject) <> Undefined Then
			
			For Each FieldName IN ControlRule.Value Do
				
				FieldNameStructure = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FieldName, ".");
				
				If CommonUseSTL.ThisIsConstant(MetadataObject) Then
					
					FieldSubstring = "Value";
					TableSubstring = MetadataObject.FullName();
					
				ElsIf CommonUseSTL.ThisIsReferenceData(MetadataObject) Then
					
					If FieldNameStructure[2] = "Attribute" OR FieldNameStructure[2] = "Attribute" Then // Not localized
						
						FieldSubstring = FieldNameStructure[3];
						TableSubstring = MetadataObject.FullName();
						
					ElsIf FieldNameStructure[2] = "TabularSection" OR FieldNameStructure[2] = "TabularSection" Then // Not localized
						
						TabularSectionName = FieldNameStructure[3];
						
						If FieldNameStructure[4] = "Attribute" OR FieldNameStructure[4] = "Attribute" Then // Not localized
							
							FieldSubstring = FieldNameStructure[5];
							TableSubstring = MetadataObject.FullName() + "." + TabularSectionName;
							
						Else
							
							RaiseExceptionFailedDefineField(FieldName, MetadataObject.FullName());
							
						EndIf;
						
					Else
						
						RaiseExceptionFailedDefineField(FieldName, MetadataObject.FullName());
						
					EndIf;
					
				ElsIf CommonUseSTL.ThisIsRecordSet(MetadataObject) Then
					
					If FieldNameStructure[2] = "Dimension" OR FieldNameStructure[2] = "Dimension"
							OR FieldNameStructure[2] = "Resource" OR FieldNameStructure[2] = "Resource"
							OR FieldNameStructure[2] = "Attribute" OR FieldNameStructure[2] = "Attribute" Then // Not localized
						
						FieldSubstring = FieldNameStructure[3];
						TableSubstring = MetadataObject.FullName();
						
					Else
						
						RaiseExceptionFailedDefineField(FieldName, MetadataObject.FullName());
						
					EndIf;
					
				Else
					
					Raise StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='The %1 metadata object is not supported!';ru='Объект метаданных %1 не поддерживается!'"), MetadataObject.FullName());
					
				EndIf;
				
				PossibleFieldTypes = Metadata.FindByFullName(FieldName).Type.Types();
				CheckedFieldTypes = New Array();
				For Each PossibleFieldType IN PossibleFieldTypes Do
					
					PossibleTypeObject = Metadata.FindByType(PossibleFieldType);
					
					If PossibleTypeObject = Undefined Then
						// Primitive type
						Continue;
					EndIf;
					
					If ExportParameters.ExportedTypes.Find(PossibleTypeObject) <> Undefined Then
						// The object is initially included in the exported types content
						Continue;
					EndIf;
					
					If AdditionallyExported.Find(PossibleTypeObject) <> Undefined Then
						// The object is already added to additionally exported content
						Continue;
					EndIf;
					
					If Not CommonUseSTL.IsReferenceDataSupportPredefinedItems(PossibleTypeObject) Then
						// The object can not contain predefined items
						Continue;
					EndIf;
					
					CheckedFieldTypes.Add(PossibleFieldType);
					
				EndDo;
				
				If CheckedFieldTypes.Count() = 0 Then
					Continue;
				EndIf;
				
				ConditionsByTypes = "";
				For Each CheckedFieldType IN CheckedFieldTypes Do
					
					If Not IsBlankString(ConditionsByTypes) Then
						ConditionsByTypes = ConditionsByTypes + " OR ";
					EndIf;
					
					ConditionsByTypes = ConditionsByTypes + "[FieldName] REF " + Metadata.FindByType(CheckedFieldType).FullName();
					
				EndDo;
				
				QueryText =
					"SELECT DISTINCT VALUETYPE([FieldName]) AS Type IN [Table] WHERE ([ConditionsByTypes]) AND [FieldName].Predefined";
				QueryText = StrReplace(QueryText, "[ConditionsByTypes]", ConditionsByTypes);
				QueryText = StrReplace(QueryText, "[Table]", TableSubstring);
				QueryText = StrReplace(QueryText, "[FieldName]", FieldSubstring);
				
				Query = New Query(QueryText);
				Selection = Query.Execute().Select();
				While Selection.Next() Do
					
					AdditionalMetadataObject = Metadata.FindByType(Selection.Type);
					If AdditionalMetadataObject <> Undefined Then
						AdditionallyExported.Add(AdditionalMetadataObject);
					EndIf;
					
				EndDo;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	CommonUseClientServer.SupplementArray(ExportParameters.ExportedTypes, AdditionallyExported, True);
	
	Container.SetExportParameters(ExportParameters);
	
	AdditionallyExportedNames = New Array();
	For Each AdditionallyExportedObject IN AdditionallyExported Do
		AdditionallyExportedNames.Add(AdditionallyExportedObject.FullName());
	EndDo;
	
	FileName = Container.CreateRandomFile("xml", DataTypeForAdditionallyExportedDataTable());
	DataExportImportService.WriteObjectToFile(AdditionallyExportedNames, FileName);
	
EndProcedure

// It is called on registering the data import arbitrary handlers.
//
// Parameters: HandlersTable - ValueTable, in
//  this procedure it is required to supplement this
//  table of values with information about registered random import data handlers. Columns:
//    MetadataObject - MetadataObject, when importing
//      the data of which the registered handler must be called,
//    Handler - CommonModule, a common module in which a random handler of the data import is implemented. Set of export procedures
//      that must be implemented in the handler, depends on
//      the set values of the following table columns, 
//    Version - String - Interface version number of exporting/importing
//      data handlers, supported by handler
//    BeforeMatchRefs - Boolean, a flag showing that a handler is to be called before matching the references (in original and current IB) that belong to the metadata object. If the True value is set - in a general module of the handler, exported procedure BeforeMatchRefs() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject before mapping the references of which the handler was called, 
//        StandardProcessor - Boolean. If procedure
//          BeforeMatchRefs() install that False parameter value instead of
//          standard mathcing refs (search of objects in the current IB with
//          the same natural key values, that were exported
//          from the IBsource) function MatchRefs() will be
//          called of general module, in
//          the procedure BeforeMatchRefs() which the value parameter StandardProcessing  was installed to False.
//          MatchRefs() function parameters:
//            Container - DataProcessorObject.DataExportImportContainerManager - manager
//              of a container that is used in the data import process. See more
//              the review to the application processing interface DataExportImportContainerManager, 
//            SourceLinksTable - ValueTable, that contains information about the refs exported from the original IB. Columns:
//               SourceRef - AnyRef, object ref of original IB, which is required to be mapped with the ref of current IB,
//               Remaining columns of equal fields of natural object key that were passed to the DataExportImportInfobase.RequiredMatchRefsOnImport() function during data export Function's return value MatchRefs() - ValueTable, columns:
//               SourceRef - AnyReference, object refs, exported from the original IB,
//               Refs - AnyRef mapped with the original reference in current IB.
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeMatchRefs() - mapping of the references corresponding to the current metadata object will not be executed.
//    BeforeImportType - Boolean, the flag showing the necessity to call the handler before importing all data objects that belong to that metadata object. If the True value is set - in a general module of the handler, exported procedure BeforeImportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject, before importing
//          all data of which the handler was called, 
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeImportType()- all data objects corresponding to the current metadata object will not be imported.
//    BeforeObjectImport - Boolean, the flag showing the necessity to call the handler before importing the data object that belongs to that metadata object. If the True value is set - in a general module of the handler, the BeforeObjectImport() exported procedure must be implemented supporting the parameters as follows:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process.
//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before importing of which the handler was called.
//          Value that is passed to procedure BeforeObjectImport() as the Object parameter value can be modified within the handler procedure BeforeObjectImport().
//        Artifacts - Array(XDTOObject) - additional data that
//          is logically inextricably associated with the data object, but not being part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
//        Cancel - Boolean. If you install this parameter value to True in the BeforeObjectImport() procedure- Import of the data object will not be executed.
//    AftertObjectImport - Boolean, the flag showing the necessity to call the handler after importing the data object that belongs to that metadata object. If the True value is set - in a general module of the handler, the AftertObjectImport() exported procedure must be implemented supporting the parameters as follows:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process. 
//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base after importing of which the handler was called.
//        Artifacts - Array(XDTOObject) - additional data that is logically inextricably associated with the data object, 
//          but not being a part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1} Artefact. 
//          It is allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
//    AfterImportType - Boolean, the flag showing the necessity to call the handler after importing all data objects that belong to that metadata object. If the True value is set - in a general module of the handler, the AfterImportType() exported procedure must be implemented supporting the parameters as follows:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process.
//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject, after importing
//          all objects of which the handler was called.
//
Procedure WhenDataExportHandlersRegistration(HandlersTable) Export
	
	NewHandler = HandlersTable.Add();
	NewHandler.Handler = UndividedPredefinedDataExportImport;
	NewHandler.BeforeDataImport = True;
	NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
	
EndProcedure

Procedure BeforeDataImport(Container) Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		
		FileName = Container.GetRandomFile(DataTypeForAdditionallyExportedDataTable());
		AdditionallyImportedNames = DataExportImportService.ReadObjectFromFile(FileName);
		
		ExportParameters = New Structure(Container.ExportParameters());
		
		For Each AdditionallyImportedObjectName IN AdditionallyImportedNames Do
			ExportParameters.ImportedTypes.Add(Metadata.FindByFullName(AdditionallyImportedObjectName));
		EndDo;
		
		Container.SetImportParameters(ExportParameters);
		
	EndIf;
	
EndProcedure

Function DataTypeForAdditionallyExportedDataTable()
	
	Return "1cfresh\UnseparatedPredefined\AdditionalObjects";
	
EndFunction

Procedure RaiseExceptionFailedDefineField(Val FieldName, Val ObjectName)
	
	Raise StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Failed to make a query to get the %1 field value of the %2 metadata object!';ru='Не удалось построить запрос получения значения поля %1 объекта мтеданных %2!'"),
		FieldName, ObjectName
	);
	
EndProcedure