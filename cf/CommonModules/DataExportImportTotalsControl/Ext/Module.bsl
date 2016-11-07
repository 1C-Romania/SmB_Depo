#Region ServiceProgramInterface

// It is called on registering the data import arbitrary handlers.
//
// Parameters: HandlersTable - ValueTable, in
//  this procedure it is required to supplement this
//  table of values with information about registered random import data handlers. Columns:
//    MetadataObject - MetadataObject, when importing
//      the data of
//    which the registered handler must be called, Handler - CommonModule, a common module in which a random handler of the data import is implemented. Set of export procedures
//      that must be implemented in the handler, depends on
//      the set 
//    values of the following table columns, Version - String - Interface version number of exporting/importing
//      data handlers,
//    supported by handler BeforeMatchRefs - Boolean, a flag showing that a handler is to be called before matching the references (in original and current IB) that belong to the metadata object. If the True value is set - in a general module of the handler, exported procedure BeforeMatchRefs() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject before mapping the references of which the handler was called, StandardProcessor - Boolean. If procedure
//          BeforeMatchRefs() install that False parameter value instead of
//          standard mathcing links (search of objects in the current IB with
//          the same natural key values, that were exported
//          from the IBsource) function MatchRefs() will be
//          called of general module, in
//          the procedure BeforeMatchRefs() which the value parameter StandardProcessing  was installed to False.
//          MatchRefs() function parameters:
//            Container - DataProcessorObject.DataExportImportContainerManager - manager
//              of a container that is used in the data import process. See more
//              the review to the application
//            processing interface DataExportImportContainerManager, SourceLinksTable - ValueTable, that contains information about the refs exported from the original IB. Columns:
//                SourceRef - AnyRef, object ref of original IB, which is required to be mapped with the ref of current IB, Remaining columns of equal fields of natural object key that were passed to the DataExportImportInfobase.RequiredMatchRefsOnImport() function during data export Function's return value MatchRefs() - ValueTable, columns:
//            SourceRef - AnyReference, object refs, exported from
//            the original IB, Refs - AnyRef mapped with the original reference in current IB.
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeMatchRefs() - mapping of the references corresponding to the current metadata object will not be executed.
//    BeforeImportType - Boolean, the flag showing the necessity to call the handler before importing all data objects that belong to that metadata object. If the True value is set - in a general module of the handler, exported procedure BeforeImportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject, before importing
//          all data of
//        which the handler was called, Cancel - Boolean. If you set True for the parameter in procedure BeforeImportType()- all data objects corresponding to the current metadata object will not be imported.
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
//        Artifacts - Array(XDTOObject) - additional data that
//          is logically inextricably associated with the data object, but not being part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
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
//        Artifacts - Array(XDTOObject) - additional data that
//          is logically inextricably associated with the data object, but not being part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
//    AfterImportType - Boolean, the flag showing the necessity to call the handler after importing all data objects that belong to that metadata object. If the True value is set - in a general module of the handler, the AfterImportType() exported procedure must be implemented supporting the parameters as follows:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject, after importing
//          all objects of which the handler was called.
//
Procedure WhenDataExportHandlersRegistration(HandlersTable) Export
	
	For Each Table IN RecordSetTablesWithTotalsSupport() Do
		
		NewHandler = HandlersTable.Add();
		NewHandler.MetadataObject = Table;
		NewHandler.Handler = DataExportImportTotalsControl;
		NewHandler.BeforeImportType = True;
		NewHandler.AfterImportType = True;
		NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
		
	EndDo;
	
EndProcedure

// Executes handlers before importing a specific data type.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// MetadataObject - MetadataObject - Metadata object.
// Cancel - Boolean - Shows that the operation is executed.
//
Procedure BeforeImportType(Container, MetadataObject, Cancel) Export
	
	Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
	
	Manager.SetTotalsUsing(False);
	
EndProcedure

// See description to the WhenAddServiceEvents() procedure of the DataExportImportServiceEvents general module
//
Procedure AfterImportType(Container, MetadataObject) Export
	
	Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
	
	Manager.SetTotalsUsing(True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function RecordSetTablesWithTotalsSupport()
	
	Result = New Array();
	
	FillSetTableByMetadataCollection(Result, Metadata.InformationRegisters);
	FillSetTableByMetadataCollection(Result, Metadata.AccumulationRegisters);
	FillSetTableByMetadataCollection(Result, Metadata.AccountingRegisters);
	
	Return Result;
	
EndFunction

Procedure FillSetTableByMetadataCollection(Sets, Collection)
	
	For Each MetadataObject IN Collection Do
		
		If CommonUseSTL.ThisIsRecordSetSupportsTotals(MetadataObject) Then
			Sets.Add(MetadataObject);
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion