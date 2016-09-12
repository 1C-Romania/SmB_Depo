#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalState

Var CurrentContainer;
Var CurrentMetadataObject;
Var CurrentHandlers;
Var CurrentRecreatedRefsWriteStream;
Var CurrentMappedRefsWriteStream;
Var CurrentSerializer;

#EndRegion

#Region ServiceProgramInterface

Procedure Initialize(Container, MetadataObject, Handlers, Serializer, RecreatedRefsWriteStream, MappedRefsWriteStream) Export
	
	CurrentContainer = Container;
	CurrentMetadataObject = MetadataObject;
	CurrentHandlers = Handlers;
	CurrentSerializer = Serializer;
	CurrentRecreatedRefsWriteStream = RecreatedRefsWriteStream;
	CurrentMappedRefsWriteStream = MappedRefsWriteStream;
	
EndProcedure

Procedure ExportData() Export
	
	Cancel = False;
	CurrentHandlers.BeforeExportType(CurrentContainer, CurrentSerializer, CurrentMetadataObject, Cancel);
	
	If Not Cancel Then
		ExportMetadataObjectData();
	EndIf;
	
	CurrentHandlers.AfterExportType(CurrentContainer, CurrentSerializer, CurrentMetadataObject);
	
EndProcedure

// Recreates references on importing.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// Refs - AnyRef - object reference.
//
Procedure RequireRecreateRefOnImport(Val Refs) Export
	
	CurrentRecreatedRefsWriteStream.RecreateRefOnImport(Refs);
	
EndProcedure

// Maps references on importing.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// Refs - AnyRef - object reference.
// NaturalKey - Structure:
// 	Key - String - natural key name.
// 	Value - AnyType - natural key value.
//
Procedure RequireMatchRefOnImport(Val Refs, Val NaturalKey) Export
	
	CurrentMappedRefsWriteStream.MatchRefOnImport(Refs, NaturalKey);
	
EndProcedure

Procedure Close() Export
	
	
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ExportMetadataObjectData()
	
	FileName = CurrentContainer.CreateFile(
		DataExportImportService.InfobaseData(), CurrentMetadataObject.FullName());
	
	WriteStream = DataProcessors.DataExportImportInfobaseDataWritingStream.Create();
	WriteStream.OpenFile(FileName, CurrentSerializer);
	
	If CommonUseSTL.ThisIsConstant(CurrentMetadataObject) Then
		
		ExportConstant(WriteStream)
		
	ElsIf CommonUseSTL.ThisIsReferenceData(CurrentMetadataObject) Then
		
		ExportReferenceObject(WriteStream);
		
	ElsIf CommonUseSTL.ThisIsRecordSet(CurrentMetadataObject) Then
		
		If CommonUseSTL.IsIndependentRecordSet(CurrentMetadataObject) Then
			
			ExportIndependentRecordSet(WriteStream);
			
		Else
			
			ExportRecordSetSubordinateToRegister(WriteStream);
			
		EndIf;
		
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en='Unexpected metadata object %1';ru='Неожиданный объект метаданных: %1'"),
			CurrentMetadataObject.FullName()
		);
		
	EndIf;
	
	WriteStream.Close();
	
	ObjectCount = WriteStream.ObjectCount();
	If ObjectCount = 0 Then
		CurrentContainer.DeleteFile(FileName);
	Else
		CurrentContainer.SetObjectsQuantity(FileName, ObjectCount);
	EndIf;
	
EndProcedure

// Exports a constant.
//
// Parameters:
// MetadataObject - MetadataObject - metadata object being exported.
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// WriteStream - record stream. The object is written to it.
// Serializer - used serializer.
// Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
//
Procedure ExportConstant(WriteStream)
	
	ValueManager = Constants[CurrentMetadataObject.Name].CreateValueManager();
	ValueManager.Read();
	
	WriteInfobaseData(WriteStream, ValueManager);
	
EndProcedure

// Exports a reference object.
//
// Parameters:
// MetadataObject - MetadataObject - metadata object being exported.
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// WriteStream - record stream. The object is written to it.
// Serializer - used serializer.
// Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
//
Procedure ExportReferenceObject(WriteStream)
	
	ObjectManager = CommonUse.ObjectManagerByFullName(CurrentMetadataObject.FullName());
	
	Selection = ObjectManager.Select();
	While Selection.Next() Do
		
		Object = Selection.Ref.GetObject();
		WriteInfobaseData(WriteStream, Object);
		
	EndDo;
	
EndProcedure

// Exports an independent record set using cursor (paging) query.
//
// Parameters:
// MetadataObject - MetadataObject - metadata object being exported.
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// WriteStream - record stream. The object is written to it.
// Serializer - used serializer.
// Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
//
Procedure ExportIndependentRecordSet(WriteStream)
	
	Status = Undefined;
	Filter = New Array;
	
	ObjectManager = CommonUse.ObjectManagerByFullName(CurrentMetadataObject.FullName());
	
	While True Do
		
		ArrayOfTables = ServiceServiceTechnologyQueries.GetDataPortionIndependentRecordSet(
			CurrentMetadataObject, Filter, 10000, False, Status);
		
		If ArrayOfTables.Count() <> 0 Then
			
			RecordSet = ObjectManager.CreateRecordSet();
			
			For Each Table IN ArrayOfTables Do
				
				For Each String IN Table Do
					
					Record = RecordSet.Add();
					FillPropertyValues(Record, String);
					
				EndDo;
				
			EndDo;
			
			WriteInfobaseData(WriteStream, RecordSet);
			
			Continue;
			
		EndIf;
		
		Break;
		
	EndDo;
	
EndProcedure

// Exports a set of records subordinate to the register.
//
// Parameters:
// MetadataObject - MetadataObject - metadata object being exported.
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// WriteStream - record stream. The object is written to it.
// Serializer - used serializer.
// Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
//
Procedure ExportRecordSetSubordinateToRegister(WriteStream)
	
	If CommonUseSTL.IsRecalculationRecordSet(CurrentMetadataObject) Then
		
		RegisterFieldName = "RecalculationObject";
		
		Substrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(CurrentMetadataObject.FullName(), ".");
		TableName = Substrings[0] + "." + Substrings[1] + "." + Substrings[3];
		
	Else
		
		RegisterFieldName = "Recorder";
		TableName = CurrentMetadataObject.FullName();
		
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	_XMLExport_Table." + RegisterFieldName + " AS Register FROM
	|" + TableName + " AS _XMLExport_Table";
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	ObjectManager = CommonUse.ObjectManagerByFullName(CurrentMetadataObject.FullName());
	
	Selection = Result.Select();
	While Selection.Next() Do
		
		RecordSet = ObjectManager.CreateRecordSet();
		RecordSet.Filter[RegisterFieldName].Set(Selection.Recorder);
		
		RecordSet.Read();
		
		WriteInfobaseData(WriteStream, RecordSet);
		
	EndDo;
	
EndProcedure

// Writes an object to XML.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// WriteStream - record stream. The object is written to it.
// Serializer - used serializer.
// Object - object that is being written.
// Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
//
Procedure WriteInfobaseData(WriteStream, Data)
	
	Cancel = False;
	Artifacts = New Array();
	CurrentHandlers.BeforeObjectExport(CurrentContainer, ThisObject, CurrentSerializer, Data, Artifacts, Cancel);
	
	If Not Cancel Then
		WriteStream.WriteInfobaseDataObject(Data, Artifacts);
	EndIf;
	
	CurrentHandlers.AfterObjectExport(CurrentContainer, ThisObject, CurrentSerializer, Data, Artifacts);
	
EndProcedure

#EndRegion

#EndIf
