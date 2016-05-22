#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns the names of
// the locked attributes for "Objects attributes editing prohibition" subsystem.
// 
// Returns:
//  Array of strings - names of the locked attributes.
// 
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	
	Result.Add("ValueType");
	
	Return Result;
	
EndFunction

// Returns the list of
// attributes allowed to be changed with the help of the group change data processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	
	EditableAttributes.Add("MultilineTextBox");
	EditableAttributes.Add("ValueFormHeader");
	EditableAttributes.Add("ValueChoiceFormHeader");
	EditableAttributes.Add("FormatProperties");
	EditableAttributes.Add("Comment");
	EditableAttributes.Add("ToolTip");
	
	Return EditableAttributes;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Changes property setting from the common property or the
// common list of the property values into the separate property with separate properties list.
//
Procedure ChangePropertiesConfiguration(Parameters, StorageAddress) Export
	
	Property            = Parameters.Property;
	CurrentSetOfProperties = Parameters.CurrentSetOfProperties;
	
	OpenProperty = Undefined;
	Block = New DataLock;
	
	LockItem = Block.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Ref", Property);
	
	LockItem = Block.Add("Catalog.AdditionalAttributesAndInformationSets");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Ref", CurrentSetOfProperties);
	
	LockItem = Block.Add("Catalog.ObjectsPropertiesValues");
	LockItem.Mode = DataLockMode.Exclusive;
	
	LockItem = Block.Add("Catalog.ObjectsPropertiesValuesHierarchy");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		PropertyObject = Property.GetObject();
		
		Query = New Query;
		If ValueIsFilled(PropertyObject.AdditionalValuesOwner) Then
			Query.SetParameter("Owner", PropertyObject.AdditionalValuesOwner);
			PropertyObject.AdditionalValuesOwner = Undefined;
			PropertyObject.Write();
		Else
			Query.SetParameter("Owner", Property);
			NewObject = ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.CreateItem();
			FillPropertyValues(NewObject, PropertyObject, , "Parent");
			PropertyObject = NewObject;
			PropertyObject.PropertySet = CurrentSetOfProperties;
			PropertyObject.Write();
			
			PropertiesSetObject = CurrentSetOfProperties.GetObject();
			If PropertyObject.ThisIsAdditionalInformation Then
				FoundString = PropertiesSetObject.AdditionalInformation.Find(Property, "Property");
				If FoundString = Undefined Then
					PropertiesSetObject.AdditionalInformation.Add().Property = PropertyObject.Ref;
				Else
					FoundString.Property = PropertyObject.Ref;
					FoundString.DeletionMark = False;
				EndIf;
			Else
				FoundString = PropertiesSetObject.AdditionalAttributes.Find(Property, "Property");
				If FoundString = Undefined Then
					PropertiesSetObject.AdditionalAttributes.Add().Property = PropertyObject.Ref;
				Else
					FoundString.Property = PropertyObject.Ref;
					FoundString.DeletionMark = False;
				EndIf;
			EndIf;
			PropertiesSetObject.Write();
		EndIf;
		
		OpenProperty = PropertyObject.Ref;
		
		OwnerMetadata = PropertiesManagementService.PropertiesSetValuesOwnerMetadata(
			PropertyObject.PropertySet, False);
		
		If OwnerMetadata = Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Error when changing settings of the %1 property.
				           |Properties set %2 is not associated with any owner of property values.'"),
				Property,
				PropertyObject.PropertySet);
		EndIf;
		
		OwnerFullName = OwnerMetadata.FullName();
		ReferenceMap = New Map;
		
		HasAdditionalValues = PropertiesManagementService.ValueTypeContainsPropertiesValues(
			PropertyObject.ValueType);
		
		If HasAdditionalValues Then
			
			If PropertyObject.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
				CatalogName = "ObjectsPropertiesValues";
				IsFolder      = "Values.IsFolder";
			Else
				CatalogName = "ObjectsPropertiesValuesHierarchy";
				IsFolder      = "False AS ThisGroup";
			EndIf;
			
			Query.Text =
			"SELECT
			|	Values.Ref AS Ref,
			|	Values.Parent AS ParentReferences,
			|	Values.IsFolder,
			|	Values.DeletionMark,
			|	Values.Description,
			|	Values.Weight
			|FROM
			|	Catalog.ObjectsPropertiesValues AS Values
			|WHERE
			|	Values.Owner = &Owner
			|TOTALS BY
			|	Ref HIERARCHY";
			Query.Text = StrReplace(Query.Text, "ObjectsPropertiesValues", CatalogName);
			Query.Text = StrReplace(Query.Text, "Values.IsFolder", IsFolder);
			
			Exporting = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
			CreateGroupsAndValues(Exporting.Rows, ReferenceMap, CatalogName, PropertyObject.Ref);
			
		ElsIf Property = PropertyObject.Ref Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Error when changing settings of the %1 property.
				           |Value type does not contain the additional values.'"),
				Property);
		EndIf;
		
		If Property <> PropertyObject.Ref
		 OR ReferenceMap.Count() > 0 Then
			
			Block = New DataLock;
			
			LockItem = Block.Add("InformationRegister.AdditionalInformation");
			LockItem.Mode = DataLockMode.Exclusive;
			LockItem.SetValue("Property", Property);
			
			LockItem = Block.Add("InformationRegister.AdditionalInformation");
			LockItem.Mode = DataLockMode.Exclusive;
			LockItem.SetValue("Property", PropertyObject.Ref);
			
			// If the original property is common then it
			// is necessary to get an object sets list (for each
			// ref), and if not only the target dataset has the replaced common  property then it is necessary to add new property and value.
			//
			// For the original common properties when the owners of their
			// values have some sets of properties, the procedure can be too long, as requires sets analysis for each
			// owner object as the procedure FillObjectPropertiesSets
			// of the common module PropertyRunPredefined has sets content predefining.
			
			OwnerWithAdditionalDetails = False;
			
			If PropertiesManagementService.IsMetadataObjectWithAdditionalDetails(OwnerMetadata) Then
				OwnerWithAdditionalDetails = True;
				LockItem = Block.Add(OwnerFullName);
				LockItem.Mode = DataLockMode.Exclusive;
			EndIf;
			
			Block.Lock();
			
			SetsAnalysisOfEachObjectOwnerRequired = False;
			
			If Property <> PropertyObject.Ref Then
				PredefinedName = StrReplace(OwnerMetadata.FullName(), ".", "_");
				
				PredefinedItems = StandardSubsystemsReUse.ReferencesByNamesOfPredefined("Catalog.AdditionalAttributesAndInformationSets");
				RootSet = PredefinedItems[PredefinedName];
				
				If RootSet <> Undefined Then
					If ValueIsFilled(CommonUse.ObjectAttributeValue(RootSet, "IsFolder")) = True Then
						SetsAnalysisOfEachObjectOwnerRequired = True;
					EndIf;
				EndIf;
			EndIf;
			
			If SetsAnalysisOfEachObjectOwnerRequired Then
				QueryAnalysis = New Query;
				QueryAnalysis.SetParameter("CommonProperty", Property);
				QueryAnalysis.SetParameter("NewPropertySet", PropertyObject.PropertySet);
				QueryAnalysis.Text =
				"SELECT TOP 1
				|	TRUE AS TrueValue
				|FROM
				|	Catalog.AdditionalAttributesAndInformationSets.AdditionalInformation AS PropertiesSets
				|WHERE
				|	PropertiesSets.Ref <> &NewPropertySet
				|	AND PropertiesSets.Ref IN(&AllObjectSet)
				|	AND PropertiesSets.Property = &CommonProperty";
			EndIf;
			
			Query = New Query;
			
			If Property = PropertyObject.Ref Then
				// If the property is not changed (already separate) and only additional
				// values list is common,  then only additional values replacement is required.
				Query.TempTablesManager = New TempTablesManager;
				
				ValueTable = New ValueTable;
				ValueTable.Columns.Add("Value", New TypeDescription(
					"CatalogRef." + CatalogName));
				
				For Each KeyAndValue IN ReferenceMap Do
					ValueTable.Add().Value = KeyAndValue.Key;
				EndDo;
				
				Query.SetParameter("ValueTable", ValueTable);
				
				Query.Text =
				"SELECT
				|	ValueTable.Value AS Value
				|INTO OldValues
				|FROM
				|	&ValueTable AS ValueTable
				|
				|INDEX BY
				|	Value";
				Query.Execute();
			EndIf;
			
			Query.SetParameter("Property", Property);
			AdditionalValuesTypes = New Map;
			AdditionalValuesTypes.Insert(Type("CatalogRef.ObjectsPropertiesValues"), True);
			AdditionalValuesTypes.Insert(Type("CatalogRef.ObjectsPropertiesValuesHierarchy"), True);
			
			// Additional information replacement.
			
			If Property = PropertyObject.Ref Then
				// If the property is not changed (already separate) and only additional
				// values list is common,  then only additional values replacement is required.
				Query.Text =
				"SELECT TOP 1000
				|	AdditionalInformation.Object
				|FROM
				|	InformationRegister.AdditionalInformation AS AdditionalInformation
				|		INNER JOIN OldValues AS OldValues
				|		ON (VALUETYPE(AdditionalInformation.Object) = Type(Catalog.ObjectsPropertiesValues))
				|			AND (NOT AdditionalInformation.Object IN (&ProcessedObjects))
				|			AND (AdditionalInformation.Property = &Property)
				|			AND AdditionalInformation.Value = OldValues.Value";
			Else
				// If the property is changed (common property becomes separated and
				// additional values are copied),then property and additional values replacement is required.
				Query.Text =
				"SELECT TOP 1000
				|	AdditionalInformation.Object
				|FROM
				|	InformationRegister.AdditionalInformation AS AdditionalInformation
				|WHERE
				|	VALUETYPE(AdditionalInformation.Object) = Type(Catalog.ObjectsPropertiesValues)
				|	AND Not AdditionalInformation.Object IN (&ProcessedObjects)
				|	AND AdditionalInformation.Property = &Property";
			EndIf;
			
			Query.Text = StrReplace(Query.Text, "Catalog.ObjectsPropertiesValues", OwnerFullName);
			
			SetOfOldRecords = InformationRegisters.AdditionalInformation.CreateRecordSet();
			NewRecordSet  = InformationRegisters.AdditionalInformation.CreateRecordSet();
			NewRecordSet.Add();
			
			ProcessedObjects = New Array;
			
			While True Do
				Query.SetParameter("ProcessedObjects", ProcessedObjects);
				Selection = Query.Execute().Select();
				If Selection.Count() = 0 Then
					Break;
				EndIf;
				While Selection.Next() Do
					Replace = True;
					If SetsAnalysisOfEachObjectOwnerRequired Then
						QueryAnalysis.SetParameter("AllObjectSet",
							PropertiesManagementService.GetObjectPropertiesSets(
								Selection.Object).UnloadColumn("Set"));
						Replace = QueryAnalysis.Execute().IsEmpty();
					EndIf;
					SetOfOldRecords.Filter.Object.Set(Selection.Object);
					SetOfOldRecords.Filter.Property.Set(Property);
					SetOfOldRecords.Read();
					If SetOfOldRecords.Count() > 0 Then
						NewRecordSet[0].Object   = Selection.Object;
						NewRecordSet[0].Property = PropertyObject.Ref;
						Value = SetOfOldRecords[0].Value;
						If AdditionalValuesTypes[TypeOf(Value)] = Undefined Then
							NewRecordSet[0].Value = Value;
						Else
							NewRecordSet[0].Value = ReferenceMap[Value];
						EndIf;
						NewRecordSet.Filter.Object.Set(Selection.Object);
						NewRecordSet.Filter.Property.Set(NewRecordSet[0].Property);
						If Replace Then
							SetOfOldRecords.Clear();
							SetOfOldRecords.DataExchange.Load = True;
							SetOfOldRecords.Write();
						Else
							ProcessedObjects.Add(Selection.Object);
						EndIf;
						NewRecordSet.DataExchange.Load = True;
						NewRecordSet.Write();
					EndIf;
				EndDo;
			EndDo;
			
			// Additional attributes replacement.
			
			If OwnerWithAdditionalDetails Then
				
				If SetsAnalysisOfEachObjectOwnerRequired Then
					QueryAnalysis = New Query;
					QueryAnalysis.SetParameter("CommonProperty", Property);
					QueryAnalysis.SetParameter("NewPropertySet", PropertyObject.PropertySet);
					QueryAnalysis.Text =
					"SELECT TOP 1
					|	TRUE AS TrueValue
					|FROM
					|	Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS PropertiesSets
					|WHERE
					|	PropertiesSets.Ref <> &NewPropertySet
					|	AND PropertiesSets.Ref IN(&AllObjectSet)
					|	AND PropertiesSets.Property = &CommonProperty";
				EndIf;
				
				If Property = PropertyObject.Ref Then
					// If the property is not changed (already separate) and only additional
					// values list is common,  then only additional values replacement is required.
					Query.Text =
					"SELECT TOP 1000
					|	CurrentTable.Ref AS Ref
					|FROM
					|	TableName AS CurrentTable
					|		INNER JOIN OldValues AS OldValues
					|		ON (NOT CurrentTable.Ref IN (&ProcessedObjects))
					|			AND (CurrentTable.Property = &Property)
					|			AND CurrentTable.Value = OldValues.Value";
				Else
					// If the property is changed (common property becomes separated and
					// additional values are copied),then property and additional values replacement is required.
					Query.Text =
					"SELECT TOP 1000
					|	CurrentTable.Ref AS Ref
					|FROM
					|	TableName AS CurrentTable
					|WHERE
					|	Not CurrentTable.Ref IN (&ProcessedObjects)
					|	AND CurrentTable.Property = &Property";
				EndIf;
				Query.Text = StrReplace(Query.Text, "TableName", OwnerFullName + ".AdditionalAttributes");
				
				ProcessedObjects = New Array;
				
				While True Do
					Query.SetParameter("ProcessedObjects", ProcessedObjects);
					Selection = Query.Execute().Select();
					If Selection.Count() = 0 Then
						Break;
					EndIf;
					While Selection.Next() Do
						CurrentObject = Selection.Ref.GetObject();
						Replace = True;
						If SetsAnalysisOfEachObjectOwnerRequired Then
							QueryAnalysis.SetParameter("AllObjectSet",
								PropertiesManagementService.GetObjectPropertiesSets(
									Selection.Ref).UnloadColumn("Set"));
							Replace = QueryAnalysis.Execute().IsEmpty();
						EndIf;
						For Each String IN CurrentObject.AdditionalAttributes Do
							If String.Property = Property Then
								Value = String.Value;
								If AdditionalValuesTypes[TypeOf(Value)] <> Undefined Then
									Value = ReferenceMap[Value];
								EndIf;
								If Replace Then
									If String.Property <> PropertyObject.Ref Then
										String.Property = PropertyObject.Ref;
									EndIf;
									If String.Value <> Value Then
										String.Value = Value;
									EndIf;
								Else
									NewRow = CurrentObject.AdditionalAttributes.Add();
									NewRow.Property = PropertyObject.Ref;
									NewRow.Value = Value;
									ProcessedObjects.Add(CurrentObject.Ref);
									Break;
								EndIf;
							EndIf;
						EndDo;
						If CurrentObject.Modified() Then
							CurrentObject.DataExchange.Load = True;
							CurrentObject.Write();
						EndIf;
					EndDo;
				EndDo;
			EndIf;
			
			If Property = PropertyObject.Ref Then
				Query.TempTablesManager.Close();
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	PutToTempStorage(OpenProperty, StorageAddress);
	
EndProcedure

Procedure CreateGroupsAndValues(Rows, ReferenceMap, CatalogName, Property, OldParent = Undefined)
	
	For Each String IN Rows Do
		If String.Ref = OldParent Then
			Continue;
		EndIf;
		
		If String.IsFolder = True Then
			NewObject = Catalogs[CatalogName].CreateFolder();
			FillPropertyValues(NewObject, String, "Name, DeletionMark");
		Else
			NewObject = Catalogs[CatalogName].CreateItem();
			FillPropertyValues(NewObject, String, "Name, Weight, DeletionMark");
		EndIf;
		NewObject.Owner = Property;
		If ValueIsFilled(String.ParentReferences) Then
			NewObject.Parent = ReferenceMap[String.ParentReferences];
		EndIf;
		NewObject.Write();
		ReferenceMap.Insert(String.Ref, NewObject.Ref);
		
		CreateGroupsAndValues(String.Rows, ReferenceMap, CatalogName, Property, String.Ref);
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
