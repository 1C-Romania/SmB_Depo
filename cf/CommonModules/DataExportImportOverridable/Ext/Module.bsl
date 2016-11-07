///////////////////////////////////////////////////////////////////////////////////////////////////////////
// DataExportImportOverridable: handling of events of data export and data import to data areas.
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Fills out an array of types for which it
// is required to use reference abstracts in export files on export.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingTypesRequireAnnotationRefsOnImport(Types) Export
	
	
	
EndProcedure

// Fills the array of types of undivided data for
// which the refs matching during data import to another infobase is supported.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingCommonDataTypesSupportingMatchingRefsOnImport(Types) Export
	
	
	
EndProcedure

// Fills the array of types of undivided data for which
// the refs mapping during data import to another infobase is not necessary as correct refs
// mapping is guaranteed by other mechanisms.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport(Types) Export
	
	
	
EndProcedure

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	
	
EndProcedure

// Called before data export.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container used in the data export process. For more information, 
//    see comment to the application interface of data processor DataExportImportContainerManager.
//
Procedure BeforeDataExport(Container) Export
	
	
	
EndProcedure

// It is called on the registration of the arbitrary handlers of data export.
//
// Parameters: HandlersTable - ValueTable, in
//  this procedure it is required to supplement this
//  table of values with information about registered random export data handlers. Columns:
//    MetadataObject - MetadataObject, when exporting
//      the data of which the registered handler must be called,
//    Handler - GeneralModule, a general module in which random handler of the data export is implemented.
//      Set of export procedures that must be implemented in the handler depends on
//      the set values of the following table columns,
//    Version - String - Interface version number of exporting/importing
//      data handlers, supported by handler,
//     BeforeExportType - Boolean, a flag showing
//      that a handler is to be called before exporting
//      all the infobase objects that are associated with the metadata object. If the True value is set - in the general module
//      of a handler, exported procedure BeforeExportType()
//      must be implemented, that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container used in the data export process. See more
//          the review to the application data processor interface DataExportImportContainerManager,
//        Serializer - XDTOSerializer, initiated with
//          support of refs abstracts execution. If a random exporting handler requires
//          additional data export - You should use SerializerXDTO
//          that is passed to the procedure BeforeExportType()
//          as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO,
//         MetadataObject - MetadataObject before exporting
//          data of which the handler was called,
//         Cancel - Boolean. If in the BeforeExportType()
//          procedure set this parameter as True - exporting of objects
//          corresponding to the current metadata object will not be executed.
//    BeforeObjectExport - Boolean, a flag showing
//      that it is required to call a handler before exporting a particular object of the infobase. If the
//      True value is set - in the general module of a handler, exported procedure BeforeObjectExport()
//      must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container used in the data export process. See more
//          the review to the application data processor interface DataExportImportContainerManager, 
//        ExportObjectManager - DataProcessorObject.DataExportImportInfobaseDataExportManager -
//          Manager of the current object export. See more the review to the
//          application data processor interface DataExportImportInfobaseDataExportManager.  
//          The parameter is passed only on the call of the handler procedures for which
//           the version higher than 1.0.0.1 is specified on registration,
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. 
//          If a random exporting handler requires
//          additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure BeforeObjectExport() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO,
//        Object - ConstantValueManager.*, CatalogObject.*, DocumentObject.*,
//          BusinessProcessObject.*, TaskObject.*, ChartOfAccountsObject.*, 
//          ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before exporting of which the handler was called.
//          Value that is passed to the BeforeObjectExport() procedure
//          as the Object parameter value can be modified
//          within the BeforeObjectExport() processor, made changes will be shown in the object
//          serialization of export files, but will not be recorded in the infobase 
//        Artifacts - Array(XDTOObject) - Set additional information logically
//          connected inextricably with the object, but not being its part (object artifacts). Artifacts
//          should formed inside handler BeforeObjectExport() and added
//          to the array passed as parameter values Artifacts. Each artifact must be
//          the XDTOobject for which type, as the base type, abstract
//          XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem. Further
//          artifacts that are formed in the procedure BeforeObjectExport(), will
//          be available in handlers procedures of data import (for more information see the procedure WhenDataImportHandlersRegistration().
//        Cancel - Boolean. If you set the parameter to True 
//            in procedure BeforeObjectExport() - the object export for which the handler was called
//            will not be executed.
//    AfterExportType() - Boolean, a flag showing that a
//      handler is to be called after exporting all objects of the infobase that belongs to that metadata object. If the
//      True value is set - in a general module of the handler, exported
//      procedure AfterExportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container used in the data export process. See more
//          the review to the application data processor interface DataExportImportContainerManager, 
//        Serializer - XDTOSerializer, initiated with
//          support of refs abstracts execution. If a random exporting handler requires
//          additional data export - You should use SerializerXDTO
//          that is passed to the procedure AfterExportType()
//          as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO, 
//         MetadataObject - MetadataObject, after exporting
//          data of which the handler was called.
//
Procedure WhenDataImportHandlersRegistration(HandlersTable) Export
	
	
	
EndProcedure

// It is called after data export.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container used in the data export process. For more
//    information, see comment to the application interface of data processor DataExportImportContainerManager.
//
Procedure AfterDataExport(Container) Export
	
	
	
EndProcedure

// Called before data import.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process. 
//    For more information, see comment to the application interface of 
//    data processor DataExportImportContainerManager.
//
Procedure BeforeDataImport(Container) Export
	
	
	
EndProcedure

// It is called on registering the data import arbitrary handlers.
//
// Parameters: HandlersTable - ValueTable, in
//  this procedure it is required to supplement this
//  table of values with information about registered random import data handlers. Columns:
//    MetadataObject - MetadataObject, when importing
//      the data of which the registered handler must be called,
//    Handler - GeneralModule, a general module in
//      which a random handler of the data import is implemented. Set of export procedures
//      that must be implemented in the handler depends on
//      the set values of the following table columns,
//    Version - String - Interface version number of exporting/importing
//      data handlers, supported by handler 
//    BeforeMatchRefs - Boolean, a flag showing
//      that a handler is to be called before matching the references (in
//      original and current IB) that belong to the metadata object. If the True value is set - in a general module
//      of the handler, exported procedure
//      BeforeMatchRefs() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process.
//          For more information, see comment to the application interface of
//          data processor DataExportImportContainerManager.
//        MetadataObject - MetadataObject before matching
//          the references of which the handler was called,
//        StandardProcessing - Boolean. If you set the procedure
//          BeforeMatchRefs() to False instead of standard mathcing refs 
//          (search of objects in the current IB with the same natural key values,
//          that were exported from the IBsource) 
//          function MatchRefs() will be called of common module,
//           in the BeforeMatchRefs() procedure of which
//          the value parameter StandardDataProcessor  was set to False.
//          MatchRefs() function parameters:
//            Container - DataProcessorObject.DataExportImportContainerManager - manager
//              of a container that is used in the data import process. See more
//              the review to the application  processing interface DataExportImportContainerManager,
//            SourceLinksTable - ValueTable, that contains information
//              about the links exported from the original IB. Columns:
//                SourceRef - AnyReference, an object ref of
//                  the initial IB that is to
//                  be matched to a ref of the current IB,
//                  Other columns equal to fields of the
//                  object natural key.
//                  The columns are passed to function Handling.ExportImportDataInfobaseDataExportManager.RequireRefMatchingOnImport() when exporting data. 
//          Return value of the function is MatchRefs() - ValueTable, columns:
//            SourceRef - AnyReference, object refs, exported from the original IB, 
//            Refs - AnyRef mapped with the original reference in current IB.
//        Cancel - Boolean. If you set True
//          for the parameter in procedure BeforeMatchRefs() - matching of
//          the links corresponding to the current metadata object will not be executed.
//    BeforeImportType - Boolean, flag showing that
//      a handler is to be called before importing
//      all data objects that belong to the metadata object. If the True value is set - in a general module
//      of the handler, exported procedure
//      BeforeImportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more
//          information, see comment to the application interface of data processor DataExportImportContainerManager.
//        MetadataObject - MetadataObject, before importing
//          all data of which the handler was called, 
//        Cancel - Boolean. If you set True for
//          the parameter in procedure BeforeImportType() - importing of all the
//          data objects corresponding to the current metadata object will not be executed.
//    BeforeObjectImport - Boolean flag of need
//      to call handler before importing the data
//      object that belongs to that metadata object. If the True value is set - in the general module
//      of a handler exported procedure
//      must be implemented BeforeObjectImport(), that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more
//          information, see comment to the application interface of data processor DataExportImportContainerManager.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before importing of which the handler was called.
//          Value that is passed to procedure BeforeObjectImport() as
//          the Object parameter value can be modified within the handler procedure BeforeObjectImport().
//        Artifacts - Array(XDTOObject) - additional data that
//          is logically inextricably associated with the data object, but not being part of it. Created in
//          exported procedures BeforeObjectExport() of data export handlers (see
//          a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be
//          the XDTOobject for which type, as the base type, abstract
//          XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
//        Cancel - Boolean. If in the procedure BeforeObjectImport()
//          install this True parameter value - Import of the data object will not be executed.
//    AftertObjectImport - Boolean flag of need
//      to call handler after importing the data
//      object that belongs to that metadata object. If the True value is set - in the general module
//      of a handler exported procedure
//      must be implemented AftertObjectImport(), that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more
//          information, see comment to the application interface of data processor DataExportImportContainerManager.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base after importing of which the handler was called.
//        Artifacts - Array(XDTOObject) - additional data that
//          is logically inextricably associated with the data object, but not being part of it. Created in
//          exported procedures BeforeObjectExport() of data export handlers (see
//          a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be
//          the XDTOobject for which type, as the base type, abstract
//          XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
//    AfterImportType - Boolean flag of need
//      to call handler after importing of all data
//      objects that belong to that metadata object. If the True value is set - in the general module
//      of a handler exported procedure
//      must be implemented AfterImportType(), that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more
//          information, see comment to the application interface of data processor DataExportImportContainerManager.
//        MetadataObject - MetadataObject, after importing
//          all objects of which the handler was called.
//
Procedure WhenDataExportHandlersRegistration(HandlersTable) Export
	
	HandlerLine = HandlersTable.Add();
	HandlerLine.MetadataObject      = Metadata.Catalogs.Counterparties;
	HandlerLine.Handler            = CommonUse.CommonModule("DataExchangeEventsSB");
	HandlerLine.BeforeObjectImport = True;
	
	HandlerLine = HandlersTable.Add();
	HandlerLine.MetadataObject      = Metadata.Catalogs.AutomaticDiscounts;
	HandlerLine.Handler            = CommonUse.CommonModule("DataExchangeEventsSB");
	HandlerLine.BeforeObjectImport = True;
	
EndProcedure

// It is called after data import.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container that is used in the data import process. For more
//    information, see comment to the application interface of data processor DataExportImportContainerManager.
//
Procedure AfterDataImport(Container) Export
	
	
	
EndProcedure

// Outdated. Recommended to use AfterDataImport().
//
Procedure AfterDataImportFromOtherMode() Export
	
	
	
EndProcedure

// Called before importing the infobase user.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container that is used in the data import process. For details,
//    see comment to the application interface of the ExportImportDataContainerManager processing, 
//  Serialization - XDTOObject {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfobaseUser, 
//    serialization of the infobase user, 
//  IBUser - InfobaseUser deserialized from export, 
//  Cancel - Boolean, import of the current infobase user will
//    be skipped during setting of this parameter value into the procedure as the False value.
//
Procedure OnImportInfobaseUser(Container, Serialization, IBUser, Cancel) Export
	
	
	
EndProcedure

// Called after importing the infobase user
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container that is used in the data import process. For details,
//    see comment to the application interface of the ExportImportDataContainerManager processing, 
//  Serialization - XDTOObject {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfobaseUser, 
//    serialization of the infobase user, 
//  IBUser - InfobaseUser deserialized from exporting.
//
Procedure AfterImportInfobaseUser(Container, Serialization, IBUser) Export
	
	
	
EndProcedure

// Called after import of all infobase users.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container that is used in the data import process. For more
//    information, see comment to the application interface of data processor DataExportImportContainerManager.
//
Procedure AfterImportInfobaseUsers(Container) Export
	
	
	
EndProcedure

//
//
