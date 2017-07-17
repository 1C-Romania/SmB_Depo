#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// For an internal use.
//
Procedure PerformMappingOfObjects(Parameters, TemporaryStorageAddress) Export
	
	PutToTempStorage(ResultMappingObjects(Parameters), TemporaryStorageAddress);
	
EndProcedure

// For an internal use.
//
Function ResultMappingObjects(Parameters) Export
	
	MappingObjects = DataProcessors.InfobaseObjectsMapping.Create();
	DataExchangeServer.ImportObjectContext(Parameters.ObjectContext, MappingObjects);
	
	Cancel = False;
	
	// Apply unapproved connection table to database.
	If Parameters.FormAttributes.OnlyApplyTableUnapprovedRecords Then
		
		MappingObjects.ApplyTableOfUnapprovedRecords(Cancel);
		
		If Cancel Then
			Raise NStr("en='Errors occurred when mapping objects.';ru='Возникли ошибки в процессе сопоставления объектов.'");
		EndIf;
		
		Return Undefined;
	EndIf;
	
	// Apply the results of automatic object mapping which are received by user.
	If Parameters.FormAttributes.ApplyResultOfAutomaticMapping Then
		
		// Add unapproved connection table.
		For Each TableRow IN Parameters.TableOfAutomaticallyMappedObjects Do
			
			FillPropertyValues(MappingObjects.TableOfUnapprovedLinks.Add(), TableRow);
			
		EndDo;
		
	EndIf;
	
	// Apply unapproved connection table to database.
	If Parameters.FormAttributes.ApplyTableOfUnapprovedRecords Then
		
		MappingObjects.ApplyTableOfUnapprovedRecords(Cancel);
		
		If Cancel Then
			Raise NStr("en='Errors occurred when mapping objects.';ru='Возникли ошибки в процессе сопоставления объектов.'");
		EndIf;
		
	EndIf;
	
	// Get mapping table.
	MappingObjects.PerformMappingOfObjects(Cancel);
	
	If Cancel Then
		Raise NStr("en='Errors occurred when mapping objects.';ru='Возникли ошибки в процессе сопоставления объектов.'");
	EndIf;
	
	Result = New Structure;
	Result.Insert("ObjectsCountInSource",       MappingObjects.ObjectsCountInSource());
	Result.Insert("ObjectsCountInReceiver",       MappingObjects.ObjectsCountInReceiver());
	Result.Insert("NumberOfObjectsMapped",   MappingObjects.NumberOfObjectsMapped());
	Result.Insert("UnmappedObjectsCount", MappingObjects.UnmappedObjectsCount());
	Result.Insert("ObjectsMappingPercent",       MappingObjects.ObjectsMappingPercent());
	Result.Insert("MappingTable",               MappingObjects.MappingTable());
	
	Result.Insert("ObjectContext", DataExchangeServer.GetObjectContext(MappingObjects));
	
	Return Result;
EndFunction

// For an internal use.
//
Procedure RunAutomaticObjectMapping(Parameters, TemporaryStorageAddress) Export
	
	PutToTempStorage(ResultOfAutomaticMappingObjects(Parameters), TemporaryStorageAddress);
	
EndProcedure

// For an internal use.
//
Function ResultOfAutomaticMappingObjects(Parameters) Export
	
	MappingObjects = DataProcessors.InfobaseObjectsMapping.Create();
	DataExchangeServer.ImportObjectContext(Parameters.ObjectContext, MappingObjects);
	
	// Define property  "UsedFieldList".
	MappingObjects.ListOfUsedFields.Clear();
	CommonUseClientServer.FillPropertyCollection(Parameters.FormAttributes.ListOfUsedFields, MappingObjects.ListOfUsedFields);
	
	// Define property "TableFieldList".
	MappingObjects.TableFieldList.Clear();
	CommonUseClientServer.FillPropertyCollection(Parameters.FormAttributes.TableFieldList, MappingObjects.TableFieldList);
	
	// Import unapproved connection table.
	MappingObjects.TableOfUnapprovedLinks.Load(Parameters.TableOfUnapprovedLinks);
	
	Cancel = False;
	
	// Get automatic object mapping table.
	MappingObjects.RunAutomaticObjectMapping(Cancel, Parameters.FormAttributes.MappingFieldList);
	
	If Cancel Then
		Raise NStr("en='Errors occurred when mapping objects automatically.';ru='Возникли ошибки в процессе автоматического сопоставления объектов.'");
	EndIf;
	
	Result = New Structure;
	Result.Insert("EmptyResult", MappingObjects.TableOfAutomaticallyMappedObjects.Count() = 0);
	Result.Insert("ObjectContext", DataExchangeServer.GetObjectContext(MappingObjects));
	
	Return Result;
EndFunction

#EndRegion

#EndIf
