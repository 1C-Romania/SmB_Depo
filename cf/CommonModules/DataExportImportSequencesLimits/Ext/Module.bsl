////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data export import".
//
////////////////////////////////////////////////////////////////////////////////

// Procedures and functions of this module
// allow you to import and export sequences borders. 

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
//      of a handler, exported procedure BeforeExportType() must be implemented,
//      that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager, 
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export - 
//          You should use SerializerXDTO that is passed to
//          the procedure BeforeExportType() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO,
//         MetadataObject - MetadataObject before exporting
//          data of which the handler was called, 
//        Cancel - Boolean. If in the BeforeExportType() procedure set this parameter as True - exporting
//          of objects corresponding to the current metadata object will not be executed.
//    BeforeObjectExport - Boolean, a flag showing that it is required to call a handler before exporting a particular object of the infobase. If the
//      True value is set - in the general module of a handler, exported
//      procedure BeforeObjectExport() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager, 
//        ExportObjectManager - DataProcessorObject.DataExportImportInfobaseDataExportManager -
//          Manager of the current object export. See more the review to the
//          application data processor interface DataExportImportInfobaseDataExportManager.   
//          The parameter is passed only on the call of handler procedures for which version higher than 1.0.0.1 is specified on registration,
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export - 
//          You should use SerializerXDTO that is passed to
//          the procedure BeforeObjectExport() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO, 
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before exporting of which the handler was called.
//          Value that is passed to the BeforeObjectExport() procedure as the Object parameter value can be modified within the BeforeObjectExport() processor, made changes will be shown in the object serialization of export files, but will not be recorded in the infobase
//       Artifacts - Array(XDTOObject) - Set additional information logically
//          connected inextricably with the object but not being its part (object artifacts). Artifacts
//          should formed inside handler BeforeObjectExport() and added to the array passed as parameter values Artifacts. 
//          Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. 
//          It is allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem. Further
//          artifacts that are formed in the procedure BeforeObjectExport(), will
//          be available in handlers procedures of data import (see review for the procedure WhenDataImportHandlersRegistration().
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeObjectExport()- object export for which the
//           handler was called will not be executed.
//    AfterExportType() - Boolean, a flag showing that a handler is to be called after exporting all objects of the infobase that belongs to that metadata object. If the
//      True value is set - in a general module of the handler, exported procedure AfterExportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager, 
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export - 
//          You should use SerializerXDTO that is passed to
//          the procedure AfterExportType() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO,
//         MetadataObject - MetadataObject, after exporting
//          data of which the handler was called.
//
Procedure WhenDataImportHandlersRegistration(HandlersTable) Export
	
	For Each Sequence IN Metadata.Sequences Do
		
		NewHandler = HandlersTable.Add();
		NewHandler.MetadataObject = Sequence;
		NewHandler.Handler = DataExportImportSequencesLimits;
		NewHandler.BeforeExportType = True;
		NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
		
	EndDo;
	
EndProcedure

// See description to the WhenAddServiceEvents() procedure of the DataExportImportServiceEvents general module
//
Procedure BeforeExportType(Container, Serializer, MetadataObject, Cancel) Export
	
	If CommonUseSTL.IsSequenceRecordSet(MetadataObject) Then
		
		Filter     = New Array;
		Status = Undefined;
		
		While True Do 
			
			ArrayOfTables = ServiceServiceTechnologyQueries.GetDataPortionIndependentRecordSet(MetadataObject, Filter, 10000, False, Status, ".Boundaries");
			If ArrayOfTables.Count() <> 0 Then
				
				FirstTable = ArrayOfTables.Get(0);
				
				RecCount = FirstTable.Count();
				
				FileName = Container.CreateFile(DataExportImportService.SequenceBoundary(), MetadataObject.FullName());
				DataExportImportService.WriteObjectToFile(FirstTable, FileName);
				Container.SetObjectsQuantity(FileName, RecCount);
				
				Continue;
				
			EndIf;
			
			Break;
		
		EndDo;
		
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en='The %1 metadata object can not be processed by the DataExportImportSequencesLimits.BeforeObjectExport() handler!';ru='Объект метаданных %1 не может быть обработан обработчиком ВыгрузкаЗагрузкаДанныхГраницПоследовательностей.ПередВыгрузкойОбъекта()!'"),
			MetadataObject.FullName());
		
	EndIf;
	
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
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process. 
//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject before mapping the references of which the handler was called, StandardProcessor - Boolean. If procedure
//          BeforeMatchRefs() install that False parameter value instead of
//          standard mathcing refs (search of objects in the current IB with
//          the same natural key values, that were exported
//          from the IBsource) function MatchRefs() will be
//          called of general module, in
//          the procedure BeforeMatchRefs() which the value parameter StandardDataProcessor  was installed to False.
//          MatchRefs() function parameters:
//            Container - DataProcessorObject.DataExportImportContainerManager - manager
//              of a container that is used in the data import process. See more
//              the review to the application processing interface DataExportImportContainerManager, 
//            SourceLinksTable - ValueTable, that contains information about the refs exported from the original IB. Columns:
//                SourceRef - AnyReference, an object ref of
//                  the initial IB that is to
//                  be matched to a ref of the current IB,
//                  Other columns equal to fields of the
//                  object natural key. 
//                  The columns are passed to function Handling.ExportImportDataInfobaseDataExportManager.RequireRefMatchingOnImport() when exporting data.
//          Return value of the function is MatchRefs() - ValueTable, columns:
//            SourceRef - AnyReference, object refs, exported from the original IB, 
//            Refs - AnyRef mapped with the original reference in current IB.
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeMatchRefs() - mapping of the references corresponding to the current metadata object will not be executed.
//    BeforeImportType - Boolean, the flag showing the necessity to call the handler before importing all data objects that belong to that metadata object. If the True value is set - in a general module of the handler, exported procedure BeforeImportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process. 
//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
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
//        Artifacts - Array(XDTOObject) - additional data that is logically inextricably associated with the data object, 
//          but not being part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. 
//          It is allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
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
//          but not being part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. 
//          It is allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
//    AfterImportType - Boolean, the flag showing the necessity to call the handler after importing all data objects that belong to that metadata object. If the True value is set - in a general module of the handler, the AfterImportType() exported procedure must be implemented supporting the parameters as follows:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process. 
//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject, after importing
//          all objects of which the handler was called.
//
Procedure WhenDataExportHandlersRegistration(HandlersTable) Export
	
	For Each Sequence IN Metadata.Sequences Do
		
		NewHandler = HandlersTable.Add();
		NewHandler.MetadataObject = Sequence;
		NewHandler.Handler = DataExportImportSequencesLimits;
		NewHandler.AfterImportType = True;
		NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
		
	EndDo;
	
EndProcedure

// See description to the WhenAddServiceEvents() procedure of the DataExportImportServiceEvents general module
//
Procedure AfterImportType(Container, MetadataObject) Export
	
	If CommonUseSTL.IsSequenceRecordSet(MetadataObject) Then
		
		SequenceManager = ServiceTechnologyIntegrationWithSSL.ObjectManagerByFullName(MetadataObject.FullName());
		
		BordersFiles = Container.GetFilesFromDirectory(DataExportImportService.SequenceBoundary(), MetadataObject.FullName());
		
		For Each BordersFile IN BordersFiles Do
			
			BordersTable = DataExportImportService.ReadObjectFromFile(BordersFile);
			
			For Each TableRow IN BordersTable Do 
				
				SequenceKey = GetSequenceKey(MetadataObject, TableRow);
				
				PointInTime = New PointInTime(TableRow.Period, TableRow.Recorder);
				SequenceManager.SetBorder(PointInTime, SequenceKey);
				
			EndDo;
			
		EndDo;
		
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en='The %1 metadata object can not be processed by the DataExportImportSequencesLimits.BeforeObjectExport() handler!';ru='Объект метаданных %1 не может быть обработан обработчиком ВыгрузкаЗагрузкаДанныхГраницПоследовательностей.ПередВыгрузкойОбъекта()!'"),
			MetadataObject.FullName());
		
	EndIf;
	
EndProcedure

// Form a key for the sequence, which consists of the content of its measurements.
//
// Parameters:
//  MetadataObject - MetadataObject - metadata object of the sequence.
//  TableRow - ValueTableRow - the row that stores the records of sequences borders.
//
// Returns:
//  Structure - sequence key: Key - name of the measurement, Value - measurement value.
//
Function GetSequenceKey(Val MetadataObject, Val TableRow)
	
	SequenceKey = New Structure;
	
	For Each Field IN MetadataObject.Dimensions Do
		SequenceKey.Insert(Field.Name, TableRow[Field.Name]);
	EndDo;
	
	Return SequenceKey;
	
EndFunction