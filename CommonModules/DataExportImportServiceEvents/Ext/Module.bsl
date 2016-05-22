////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data export import".
//
////////////////////////////////////////////////////////////////////////////////

// Procedures and functions of this module contain service events that
// can be signed up by an applicative developer for the extended possibility of data export and import.
//

// Announces service events of the DataExportImport subsystem:
//
// See details of the same procedure in the StandardSubsystemsServer module.
//
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Fills out the array of types for which you need to use the refs annotation in the export files when exporting.
	//
	// Parameters:
	//  Types - Array(MetadataObject)
	//
	// Syntax:
	// Procedure WhenFillingTypesRequireAnnotationRefsOnExport (Types) Export
	//
	// (The same as RedefinedDataExportImport.WhenFillingTypesRequireAnnotationRefsOnExport).
	ServerEvents.Add("ServiceTechnology.DataExportImport\WhenFillingTypesRequireAnnotationRefsOnImport");
	
	// Fill the array of undivided data types for which
	// matching refs during data import to another info base is supported.
	//
	// Parameters:
	//  Types - Array(MetadataObject)
	//
	// Syntax:
	// Procedure WhenFillingCommonDataTypesSupportingMatchingRefsOnImport(Types)
	// Export (the same as RedefinedDataExportImport.WhenFillingCommonDataTypesSupportingMatchingRefsOnImport).
	ServerEvents.Add("ServiceTechnology.DataExportImport\WhenFillingCommonDataTypesSupportingMatchingRefsOnImport");
	
	// Fill the array of undivided data types for which matching
	// refs during data import to another info base is not necessary. correct matching
	// of refs is guaranteed by using other mechanisms.
	//
	// Parameters:
	//  Types - Array(MetadataObject)
	//
	// Syntax:
	// Procedure WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport(Types)
	// Export (the same as RedefinedDataExportImport.WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport).
	ServerEvents.Add("ServiceTechnology.DataExportImport\WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport");
	
	// Fills the array of types excluded from the import and export of data.
	//
	// Parameters:
	//  Types - Array(Types).
	//
	// Syntax:
	// Procedure WhenFillingTypesExcludedFromExportImport(Types)
	// Export (the same as RedefinedDataExportImport.WhenFillingTypesExcludedFromExportImport).
	ServerEvents.Add("ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport");
	
	// Called before data export.
	//
	// Parameters:
	//  Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
	//
	// Syntax:
	// Procedure BeforeDataExport(Container)
	// Export (the same as RedefinedDataExportImport.BeforeDataExport).
	ServerEvents.Add("ServiceTechnology.DataExportImport\BeforeDataExport");
	
	// It is called on the registration of the arbitrary handlers of data export.
	//
	// Parameters: HandlersTable - ValueTable, in
	//  this procedure it is required to supplement this
	//  table of values with information about registered random export data handlers. Columns:
	//    MetadataObject - MetadataObject, when exporting
	//      the data of which the registered handler must be called, 
	//    Handler - GeneralModule, a general module in
	//      which random handler of the data export implemented. Set of export procedures,
	//      that must be implemented in a handler, depend on
	//      the values settings of the value table following columns, 
	//    BeforeExportType - Boolean, a flag showing that a handler is to be called before exporting all the infobase objects that are associated with the metadata object. If the True value is set - in the general module
	//      of a handler, exported procedure BeforeExportType() must be implemented,
	//      and that supports the following parameters:
	//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
	//          the review to the application data processor interface DataExportImportContainerManager, 
	//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export 
	//          In this case you should use SerializerXDTO that is passed to
	//          the procedure BeforeExportType() as the parameter value of Serializer rather
	//          than received by using the global context properties SerializerXDTO, 
	//        MetadataObject - MetadataObject before exporting
	//          data of which the handler was called, 
	//        Cancel - Boolean. If in the BeforeExportType() procedure set this parameter as True - exporting
	//          of objects corresponding to the current metadata object will not be executed.
	//    BeforeObjectExport - Boolean, a flag showing that it is required to call a handler before exporting a particular object of the infobase. If the
	//      True value is set - in the general module of a handler, exported
	//      procedure BeforeObjectExport() must be implemented that supports the following parameters:
	//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
	//          the review to the application data processor interface DataExportImportContainerManager,
	//         ExportObjectManager - DataProcessorObject.DataExportImportInfobaseDataExportManager -
	//          Manager of the current object export. See more the review to the
	//          application data processor interface DataExportImportInfobaseDataExportManager. 
	//          The parameter is passed only on the call of the handler procedures for which version higher than 1.0.0.1 is specified on registration,
  //        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export
	//          In this case you should use SerializerXDTO that is passed to the procedure BeforeObjectExport()
	//          as the parameter value of Serializer rather
	//          than received by using the global context properties SerializerXDTO,
	//        Object - ConstantValueManager.*,
	//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
	//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
	//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
	//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
	//          data object of the info base before exporting of which the handler was called.
	//          Value that is passed to the BeforeObjectExport() procedure as the Object parameter value can be modified within the BeforeObjectExport() processor, made changes will be shown in the object serialization of export files, but will not be recorded in the infobase
 //         Artifacts - Array(XDTOObject) - Set additional information logically
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
	//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export 
	//          In this case you should use SerializerXDTO that is passed to
	//          the procedure AfterExportType() as the parameter value of Serializer rather
	//          than received by using the global context properties SerializerXDTO,
	//        MetadataObject - MetadataObject, after exporting
	//          data of which the handler was called.
	//
	// Syntax:
	// Procedure WhenDataExportHandlersRegistration(HandlersTable)
	// Export (the same as RedefinedDataExportImport.WhenDataExportHandlersRegistration).
	ServerEvents.Add("ServiceTechnology.DataExportImport\WhenDataImportHandlersRegistration");
	
	// It is called after data export.
	//
	// Parameters:
	//  Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
	//
	// Syntax:
	// Procedure AfterDataExport(Container)
	// Export (the same as RedefinedDataExportImport.AfterDataExport).
	ServerEvents.Add("ServiceTechnology.DataExportImport\AfterDataExport");
	
	// Called before data import.
	//
	// Parameters:
	//  Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process. 
	//    For more information, see a comment to the DataExportImportContainerManager application interface processor.
	//
	// Syntax:
	// Procedure BeforeDataImport(Container) Export 
	// (the same as RedefinedDataExportImport.BeforeDataImport).
	ServerEvents.Add("ServiceTechnology.DataExportImport\BeforeDataImport");
	
	// It is called on registering the data import arbitrary handlers.
	//
	// Parameters: HandlersTable - ValueTable, in
	//  this procedure it is required to supplement this
	//  table of values with information about registered random import data handlers. Columns:
	//    MetadataObject - MetadataObject, when importing
	//      the data of which the registered handler must be called, 
	//    Handler - CommonModule, a common module in which a random handler of the data import is implemented. Set of export procedures,
	//      that must be implemented in a handler, depend on
	//      the values settings of the value table following columns,
	//     BeforeMatchingRefs - Boolean, a flag showing that a handler is to be called before matching the references (in original and current IB) that belong to the metadata object. If the True value is set - in a general module of the handler, exported procedure BeforeMatchRefs() must be implemented that supports the following parameters:
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
	//           The columns are passed to function Handling.ExportImportDataInfobaseDataExportManager.RequireRefMatchingOnImport() when exporting data. Return value of the function is MatchRefs() - ValueTable, columns:
	//            SourceRef - AnyReference, object refs, exported from
	//            the original IB, Refs - AnyRef mapped with the original reference in current IB.
	//        Cancel - Boolean. If you set True for the parameter in procedure BeforeMatchRefs() - mapping of the references corresponding to the current metadata object will not be executed.
	//    BeforeImportType - Boolean, the flag showing the necessity to call the handler before importing all data objects that belong to that metadata object. If the True value is set - in a general module of the handler, exported procedure BeforeImportType() must be implemented that supports the following parameters:
	//        Container - DataProcessorObject.DataExportImportContainerManager - manager
	//          of a container that is used in the data import process. For more information, see a comment to the DataExportImportContainerManager application interface processor.
	//        MetadataObject - MetadataObject, before importing
	//          all data of which the handler was called,
	//        Cancel - Boolean. If you set True for the parameter in procedure BeforeImportType()- all data objects corresponding to the current metadata object will not be imported.
	//    BeforeObjectImport - Boolean, the flag showing the necessity to call the handler before importing the data object that belongs to that metadata object. If the True value is set - in a general module of the handler, the BeforeObjectImport() exported procedure must be implemented supporting the parameters as follows:
	//        Container - DataProcessorObject.DataExportImportContainerManager - manager
	//          of a container that is used in the data import process. For more information, see a comment to the DataExportImportContainerManager application interface processor.
	//        Object - ConstantValueManager.*,
	//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
	//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
	//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
	//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
	//          data object of the info base before importing of which the handler was called.
	//          Value that is passed to procedure BeforeObjectImport() as the Object parameter value can be modified within the handler procedure BeforeObjectImport().
	//        Artifacts - Array(XDTOObject) - additional data that is logically inextricably associated with the data object, 
	//          but not being a part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
	//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
	//        Cancel - Boolean. If you install this parameter value to True in the BeforeObjectImport() procedure- Import of the data object will not be executed.
	//    AftertObjectImport - Boolean, the flag showing the necessity to call the handler after importing the data object that belongs to that metadata object. If the True value is set - in a general module of the handler, the AftertObjectImport() exported procedure must be implemented supporting the parameters as follows:
	//        Container - DataProcessorObject.DataExportImportContainerManager - manager
	//          of a container that is used in the data import process. For more information, see a comment to the DataExportImportContainerManager application interface processor.
	//        Object - ConstantValueManager.*,
	//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
	//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
	//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
	//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
	//          data object of the info base after importing of which the handler was called.
	//        Artifacts - Array(XDTOObject) - additional data that is logically inextricably associated with the data object,
	//          but not being part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
	//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
	//    AfterImportType - Boolean, the flag showing the necessity to call the handler after importing all data objects that belong to that metadata object. If the True value is set - in a general module of the handler, the AfterImportType() exported procedure must be implemented supporting the parameters as follows:
	//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process.
	//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
	//        MetadataObject - MetadataObject, after importing
	//          all objects of which the handler was called.
	//
	// Syntax:
	// Procedure WhenDataImportHandlersRegistration(HandlersTable)
	// Export (the same as RedefinedDataExportImport.WhenDataImportHandlersRegistration).
	ServerEvents.Add("ServiceTechnology.DataExportImport\WhenDataExportHandlersRegistration");
	
	// It is called after data import.
	//
	// Parameters:
	//  Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process. 
	//    For more information, see a comment to the DataExportImportContainerManager application interface processor.
	//
	// Syntax:
	// Procedure AfterDataImport(Container) Export 
	// (the same as RedefinedDataExportImport.AfterDataImport).
	ServerEvents.Add("ServiceTechnology.DataExportImport\AfterDataImport");
	
	// It is called after the data import from another model.
	//
	// Syntax:
	// Procedure AfterDataImportFromAnotherModel() Export 
	// (the same as RedefinedDataExportImport).AfterDataImportFromOtherMode).
	ServerEvents.Add("ServiceTechnology.DataExportImport\AfterDataImportFromOtherMode");
	
	// Called before importing the infobase user.
	//
	// Parameters:
	//  Container - DataProcessorObject.DataExportImportContainerManager - manager
	//    of a container that is used in the data import process. For details,
	//    see comment to the application interface of the ExportImportDataContainerManager processing,
	//  Serialization - XDTOObject
	//    {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfobaseUser, serialization of
	//    the infobase user, IBUser - InfobaseUser deserialized
	//    from export, Cancel - Boolean, import of the current infobase user will
	//    be skipped during setting of this parameter value into the procedure as the False value.
	//
	// Syntax:
	// Procedure OnImportInfobaseUser(Container, Serialization, IBUser, Cancel) Export 
	// (the same as RedefinedDataExportImport).OnImportInfobaseUser).
	ServerEvents.Add("ServiceTechnology.DataExportImport\OnImportInfobaseUser");
	
	// Called after importing the infobase user
	//
	// Parameters:
	//  Container - DataProcessorObject.DataExportImportContainerManager - manager
	//    of a container that is used in the data import process. For details,
	//    see comment to the application interface of the ExportImportDataContainerManager processing,
	//   Serialization - XDTOObject
	//    {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfobaseUser, serialization of
	//    the infobase user, IBUser - InfobaseUser deserialized from exporting.
	//
	// Syntax:
	// Procedure AfterImportInfobaseUser(Container, Serialization, IBUser, Cancel) Export 
	// (the same as RedefinedDataExportImport).AfterImportInfobaseUser).
	ServerEvents.Add("ServiceTechnology.DataExportImport\AfterImportInfobaseUser");
	
	// Called after import of all infobase users.
	//
	// Parameters:
	//  Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process.
	//    For more information, see a comment to the DataExportImportContainerManager application interface processor.
	//
	// Syntax:
	// Procedure AfterImportInfobaseUsers(Container) Export 
	// (the same as RedefinedDataExportImport.AfterImportInfobaseUsers).
	ServerEvents.Add("ServiceTechnology.DataExportImport\AfterImportInfobaseUsers");
	
	ServerEvents.Add("ServiceTechnology.DataExportImport\WhenDefiningTypesRequireImportToLocalVersion");
	
	ServerEvents.Add("ServiceTechnology.DataExportImport\OnDefiningMetadataObjectsExcludedFromExportImport");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// Return interface version of export/import data handlers 1.0.0.0.
//
Function HandlersVersion1_0_0_0() Export
	
	Return "1.0.0.0";
	
EndFunction

// Return interface version of export/import data handlers 1.0.0.1.
//
Function HandlersVersion1_0_0_1() Export
	
	Return "1.0.0.1";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Initialization of events during data export

// Form the metadata array that requires annotation of references during exporting.
//
// Returns:
//  FixedArray - metadata array.
//
Function GetTypesRequireAnnotationRefsOnExport() Export
	
	Types = New Array();
	
	// Integrated handlers
	UndividedDataExportImport.WhenFillingTypesRequireAnnotationRefsOnImport(Types);
	DataExportImportOverridable.WhenFillingTypesRequireAnnotationRefsOnImport(Types);
	JointlySeparatedDataExportImport.WhenFillingTypesRequireAnnotationRefsOnImport(Types);
	PredefinedDataExportImport.WhenFillingTypesRequireAnnotationRefsOnImport(Types);
	ExportImportExchangePlanNodes.WhenFillingTypesRequireAnnotationRefsOnImport(Types);
	
	// Events handlers SSL
	ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.DataExportImport\WhenFillingTypesRequireAnnotationRefsOnImport");
	For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
		ProgrammingEventsHandlerSSL.Module.WhenFillingTypesRequireAnnotationRefsOnImport(Types);
	EndDo;
	
	// Redefined procedure
	DataExportImportOverridable.WhenFillingTypesRequireAnnotationRefsOnImport(Types);
	
	Return New FixedArray(Types);
	
EndFunction

// Form the metadata array that supports matching of references on import.
//
// Returns:
// FixedArray - metadata array.
//
Function GetCommonDataTypesSupportMatchingRefsOnImport() Export
	
	Types = New Array();
	
	// Events handlers SSL
	ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.DataExportImport\WhenFillingCommonDataTypesSupportingMatchingRefsOnImport");
	For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
		ProgrammingEventsHandlerSSL.Module.WhenFillingCommonDataTypesSupportingMatchingRefsOnImport(Types);
	EndDo;
	
	// Redefined procedure
	DataExportImportOverridable.WhenFillingCommonDataTypesSupportingMatchingRefsOnImport(Types);
	
	Return New FixedArray(Types);
	
EndFunction

// Form the metadata array that does not require matching of references on import.
//
// Returns:
//  FixedArray - metadata array.
//
Function GetCommonDataTypesDoNotRequireMatchingRefsOnImport() Export
	
	Types = New Array();
	
	// Events handlers SSL
	ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.DataExportImport\WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport");
	For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
		ProgrammingEventsHandlerSSL.Module.WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport(Types);
	EndDo;
	
	// Redefined procedure
	DataExportImportOverridable.WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport(Types);
	
	Return New FixedArray(Types);
	
EndFunction

// Forms the metadata array that is excluded from the import/export.
//
// Returns:
//  FixedArray - metadata array.
//
Function GetTypesExcludedFromExportImport() Export
	
	Types = New Array();
	
	// Events handlers SSL
	ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport");
	For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
		ProgrammingEventsHandlerSSL.Module.WhenFillingTypesExcludedFromExportImport(Types);
	EndDo;
	
	// Redefined procedure
	DataExportImportOverridable.WhenFillingTypesExcludedFromExportImport(Types);
	
	Return New FixedArray(Types);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Initialization of events during data import


// Return the types dependencies during replacing of refs.
//
// Return value:
// Map:
// 	Key - String - the metadata name that depends on other metadata.
// 	Value - Array - the array of the metadata names on which depends the metadata, that is stored in the key.
//
Function GetTypesDependenciesOnReplacingRefs() Export
	
	// Integrated handlers
	Return UndividedDataExportImport.TypesDependenciesOnReplacingRefs();
	
EndFunction

// Perform some actions after data import
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container that is used in the data import process. For details,
//    see comment to the application interface of the ExportImportDataContainerManager processing,
//   Serialization - XDTOObject
//    {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfobaseUser, serialization of the infobase user,
//   IBUser - InfobaseUser deserialized from export, 
//   Cancel - Boolean, import of the current infobase user will
//    be skipped during setting of this parameter value into the procedure as the False value.
//
Procedure ExecuteActionsOnImportInfobaseUser(Container, Serialization, IBUser, Cancel) Export
	
	// Events handlers SSL
	ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.DataExportImport\OnImportInfobaseUser");
	For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
		ProgrammingEventsHandlerSSL.Module.OnImportInfobaseUser(Container, Serialization, IBUser, Cancel);
	EndDo;
	
	// Redefined procedure
	DataExportImportOverridable.OnImportInfobaseUser(Container, Serialization, IBUser, Cancel);
	
EndProcedure

// Execute some actions after the import of infobase user.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container that is used in the data import process. For details,
//    see comment to the application interface of the ExportImportDataContainerManager processing, 
//  Serialization - XDTOObject
//    {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfobaseUser, serialization of the infobase user, 
//  IBUser - InfobaseUser, deserialized from exporting,
//
Procedure ExecuteActionsAfterImportInfobaseUser(Container, Serialization, IBUser) Export
	
	// Events handlers SSL
	ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.DataExportImport\AfterImportInfobaseUser");
	For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
		ProgrammingEventsHandlerSSL.Module.AfterImportInfobaseUser(Container, Serialization, IBUser);
	EndDo;
	
	// Redefined procedure
	DataExportImportOverridable.AfterImportInfobaseUser(Container, Serialization, IBUser);
	
EndProcedure

// Execute some actions after the import of infobase users.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container that is used in the data import process. See more
//    the review to the application data processor interface DataExportImportContainerManager,
//
Procedure ExecuteActionsAfterImportInfobaseUsers(Container) Export
	
	// Events handlers SSL
	ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.DataExportImport\AfterImportInfobaseUsers");
	For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
		ProgrammingEventsHandlerSSL.Module.AfterImportInfobaseUsers(Container);
	EndDo;
	
	// Redefined procedure
	DataExportImportOverridable.AfterImportInfobaseUsers(Container);
	
EndProcedure
