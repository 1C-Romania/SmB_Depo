#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure updates catalog data by the configuration metadata.
//
// Parameters:
//  HasChanges - Boolean (return value) - value True is
//                  returned to this parameter if the record was created, otherwise it does not change.
//
//  HasDeleted - Boolean (return value) - True value is
//                  returned to this parameter if at least one catalog item
//                  is marked for deletion, otherwise, is not changed.
//
//  CheckOnly - Boolean (return value) - does not make
//                  any changes, only selects the HasChanges, HasDeletion check boxes.
//
Procedure UpdateCatalogData(HasChanges = False, HasDeleted = False, CheckOnly = False) Export
	
	ExecuteDataRefreshing(HasChanges, HasDeleted, CheckOnly);
	
EndProcedure

// Required to export all metadata
// objects IDs to DIB subordinate nodes if catalog is not included to DIB.
// It can also be used for catalog data repair in DIB-nodes.
//
Procedure RegisterFullUpdateForDescendantsOfRIB() Export
	
	CheckUse();
	
	If CommonUse.IsSubordinateDIBNode() Then
		Return;
	EndIf;
	
	NodesRIB = New Array;
	For Each ExchangePlan IN Metadata.ExchangePlans Do
		If ExchangePlan.DistributedInfobase
		   AND ExchangePlan.Content.Contains(Metadata.Catalogs.MetadataObjectIDs)Then
			
		ExchangePlanManager = CommonUse.ObjectManagerByFullName(ExchangePlan.FullName());
		Selection = ExchangePlanManager.Select();
		While Selection.Next() Do
			If Selection.Ref <> ExchangePlanManager.ThisNode() Then
				NodesRIB.Add(Selection.Ref);
			EndIf;
		EndDo;
		EndIf;
	EndDo;
	
	If NodesRIB.Count() > 0 Then
		StandardSubsystemsServer.ExchangePlansManager().RecordChanges(
			NodesRIB, Metadata.Catalogs.MetadataObjectIDs);
	EndIf;
	
EndProcedure

// Returns the list of
// attributes allowed to be changed with the help of the group change data processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	
	Return EditableAttributes;
	
EndFunction

#EndRegion

#Region ServiceProgramInterface

// Returns True if check, update and replacement of duplicates is comptete.
//
// Parameters:
//  Message - Boolean - if you pass True, then an
//             exception of error contacting unupdated parameters of application work will be thrown.
//
Function DataUpdated(Message = False) Export
	
	If Message Then
		Cancel = Undefined;
	Else
		Cancel = False;
	EndIf;
	
	StandardSubsystemsServer.CheckForUpdatesApplicationWorkParameters(
		"BasicFunctionalityParameters", "MetadataObjectIDs", Cancel);
	
	Return Cancel <> True;
	
EndFunction

// Procedure updates catalog data by the configuration metadata.
//
// Parameters:
//  HasChanges - Boolean (return value) - value True is
//                  returned to this parameter if the record was created, otherwise it does not change.
//
//  HasDeleted - Boolean (return value) - True value is
//                  returned to this parameter if at least one catalog item
//                  is marked for deletion, otherwise, is not changed.
//
//  CheckOnly - Boolean (return value) - does not make
//                  any changes but only selects the HasChanges,
//                  HasDeleted, HasCriticalChanges check boxes.
//
//  AreCriticalChanges - (return value) - the True value
//                  is returned to this parameter if critical changes are found, otherwise, it is not changed.
//                    Critical changes (only for those that are not marked for deletion):
//                    - change the FullName attribute,
//                    - add catalog new item.
//                  IN general, critical changes require the exclusive mode.
//
//  CriticalChangesList - String (return value) - contains
//                  the full names of metadata objects that
//                  are added or required to be added, as well as full names of metadata objects, full names of which are changed or required to be changed.
//
Procedure ExecuteDataRefreshing(HasChanges, HasDeleted, CheckOnly = False,
			AreCriticalChanges = False, CriticalChangesList = "") Export
	
	CheckUse();
	
	SetPrivilegedMode(True);
	
	IsCurrentChanges = False;
	ReplaceSubordinateNodeDuplicatesOnImport(CheckOnly, IsCurrentChanges);
	If IsCurrentChanges Then
		HasChanges = True;
	EndIf;
	
	MetadataObjectProperties = MetadataObjectProperties();
	CatalogManager = CommonUse.ObjectManagerByFullName("Catalog.MetadataObjectIDs");
	
	// found - state when ID is found for the metadata objects.
	MetadataObjectProperties.Columns.Add("found", New TypeDescription("Boolean"));
	
	// Update order:
	// 1. Rename metadata objects (considering underlying subsystems).
	// 2. Update predefined IDs (metadata objects collections).
	// 3. Update metadata objects IDs that have metada object key.
	// 4. Update metadata objects IDs that do not have metadata object key.
	// 5. IN process 3 and 4 deletion mark of IDs duplicates (by full names).
	// 6. Add new IDs of the metadata objects.
	// 7. Update metadata objects IDs parents and write the updated ones.
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.MetadataObjectIDs");
	LockItem.Mode = DataLockMode.Exclusive;
	
	SwitchOffSoleMode = False;
	BeginTransaction();
	Try
		Block.Lock();
		
		Exporting = ExportAllIDs();
		Exporting.Columns.Add("Updated", New TypeDescription("Boolean"));
		Exporting.Columns.Add("MetadataObject");
		Exporting.Columns.Delete("NewRef");
		
		If Not CommonUse.IsSubordinateDIBNode() Then
			// Rename full names before data processor (for DIB only in the main node).
			RenameDescriptionFulls(Exporting);
		EndIf;
		
		MetadataObjectsRenamingsList = "";
		AreCurrentCriticalChanges = False;
		
		// Process metadata objects IDs.
		For Each Properties IN Exporting Do
			
			// Check and update IDs properties of metadata objects collections.
			If Properties.IsCollection Then
				CheckUpdateCollectionProperties(Properties);
				Continue;
			EndIf;
			
			MetadataObjectKey = Properties.MetadataObjectKey;
			MetadataObject = MetadataObjectByKey(MetadataObjectKey);
			
			If MetadataObject = Undefined Then
				// If metadata object does not have a key, then it can be found only by a full name.
				MetadataObject = MetadataFindByFullName(Properties.FullName);
			Else
				// If the metadata object is removed for
				// the purpose of restructuring, then old ID should
				// be used for the new metadata object and for the old metadata objects you should create new IDs.
				If Upper(Left(MetadataObject.Name, StrLen("Delete"))) =  Upper("Delete")
				   AND Upper(Left(Properties.Name,         StrLen("Delete"))) <> Upper("Delete") Then
					
					NewMetadataObject = MetadataFindByFullName(Properties.FullName);
					If NewMetadataObject <> Undefined Then
						MetadataObject = NewMetadataObject;
						MetadataObjectKey = Undefined; // To update ID.
					EndIf;
				EndIf;
			EndIf;
			
			// If metadata object is found by key or
			// full name, then you should prepare metadata object properties string.
			If MetadataObject <> Undefined Then
				PropertiesOfObject = MetadataObjectProperties.Find(MetadataObject.FullName(), "FullName");
				If PropertiesOfObject = Undefined Then
					MetadataObject = Undefined;
				Else
					Properties.MetadataObject = MetadataObject;
				EndIf;
			EndIf;
			
			If MetadataObject = Undefined OR PropertiesOfObject.found Then
				// If metadata object is not found
				// or found again, then you should put ID for deletion.
				PropertiesUpdated = False;
				RefreshPropertiesMarkedForDelete(Properties, PropertiesUpdated, HasDeleted);
				If PropertiesUpdated Then
					Properties.Updated = True;
				EndIf;
			Else
				// Update properties of existing metadata objects if they are changed.
				PropertiesOfObject.found = True;
				If Properties.Description              <> PropertiesOfObject.Description
				 OR Properties.CollectionOrder          <> PropertiesOfObject.CollectionOrder
				 OR Properties.Name                       <> PropertiesOfObject.Name
				 OR Properties.Synonym                   <> PropertiesOfObject.Synonym
				 OR Properties.FullName                 <> PropertiesOfObject.FullName
				 OR Properties.FullSynonym             <> PropertiesOfObject.FullSynonym
				 OR Properties.WithoutData                 <> PropertiesOfObject.WithoutData
				 OR Properties.EmptyRefValue      <> PropertiesOfObject.EmptyRefValue
				 OR Properties.PredefinedDataName <> ""
				 OR Properties.DeletionMark
				 OR MetadataObjectKey = Undefined
				 OR PropertiesOfObject.WithoutMetadataObjectKey
				     AND MetadataObjectKey <> Type("Undefined") Then
					
					If Upper(Properties.FullName) <> Upper(PropertiesOfObject.FullName) Then
						AreCurrentCriticalChanges = True;
						AreCriticalChanges = True;
						MetadataObjectsRenamingsList = MetadataObjectsRenamingsList
							+ ?(ValueIsFilled(MetadataObjectsRenamingsList), "," + Chars.LF, "")
							+ Properties.FullName + " -> " + PropertiesOfObject.FullName;
					EndIf;
					
					// Set new properties of the metadata object ID.
					FillPropertyValues(Properties, PropertiesOfObject);
					
					Properties.PredefinedDataName = "";
					
					If MetadataObjectKey = Undefined
					 OR PropertiesOfObject.WithoutMetadataObjectKey
					     AND MetadataObjectKey <> Type("Undefined") Then
						
						Properties.MetadataObjectKey = MetadataObjectKey(PropertiesOfObject.FullName);
					EndIf;
					
					Properties.DeletionMark = False;
					Properties.Updated = True;
				EndIf;
			EndIf;
		EndDo;
		
		ListOfNewMetadataObjects = "";
		
		// Add IDs of new metadata objects.
		For Each PropertiesOfObject IN MetadataObjectProperties.FindRows(New Structure("found", False)) Do
			Properties = Exporting.Add();
			FillPropertyValues(Properties, PropertiesOfObject);
			Properties.IsNew = True;
			Properties.Ref = GetRef();
			Properties.DeletionMark  = False;
			Properties.MetadataObject = PropertiesOfObject.MetadataObject;
			Properties.MetadataObjectKey = MetadataObjectKey(Properties.FullName);
			AreCurrentCriticalChanges = True;
			AreCriticalChanges = True;
			ListOfNewMetadataObjects = ListOfNewMetadataObjects
				+ ?(ValueIsFilled(ListOfNewMetadataObjects), "," + Chars.LF, "")
				+ PropertiesOfObject.FullName;
		EndDo;
		
		CriticalChangesList = "";
		If ValueIsFilled(MetadataObjectsRenamingsList) Then
			CriticalChangesList = NStr("en = 'Rename metadata objects IDs OldFullName -> NewFullName:'")
				+ Chars.LF + MetadataObjectsRenamingsList + Chars.LF + Chars.LF;
		EndIf;
		If ValueIsFilled(ListOfNewMetadataObjects) Then
			CriticalChangesList = CriticalChangesList
				+ NStr("en = 'Add new IDs of the metadata objects:'")
				+ Chars.LF + ListOfNewMetadataObjects + Chars.LF;
		EndIf;
		
		If Not (CheckOnly OR ExclusiveMode())
		   AND AreCurrentCriticalChanges Then
			
			CommitTransaction();
			Try
				SetExclusiveMode(True);
			Except
				BeginTransaction();
				Raise;
			EndTry;
			SwitchOffSoleMode = True;
			BeginTransaction();
		EndIf;
		
		// Update metadata objects IDs parents.
		For Each Properties IN Exporting Do
			
			If Not Properties.IsCollection Then
				PropertiesOfObject = MetadataObjectProperties.Find(Properties.FullName, "FullName");
				NewParent = EmptyRef();
				
				If PropertiesOfObject <> Undefined Then
				
					If Not ValueIsFilled(PropertiesOfObject.ParentFullName) Then
						// Metadata objects collection.
						NewParent = PropertiesOfObject.Parent;
					Else
						// Not the metadata objects collection, for example, subsystem.
						ParentDescription = Exporting.Find(PropertiesOfObject.ParentFullName, "FullName");
						If ParentDescription <> Undefined Then
							NewParent = ParentDescription.Ref;
						EndIf;
					EndIf;
				EndIf;
				
				If Properties.Parent <> NewParent Then
					Properties.Parent = NewParent;
					Properties.Updated = True;
				EndIf;
			EndIf;
			
			If Properties.IsNew Then
				TableObject = CreateItem();
				TableObject.SetNewObjectRef(Properties.Ref);
				
			ElsIf Properties.Updated Then
				TableObject = Properties.Ref.GetObject();
			Else
				Continue;
			EndIf;
			
			IsCurrentChanges = True;
			HasChanges = True;
			If CheckOnly Then
				CommitTransaction();
				Return;
			EndIf;
			
			FillPropertyValues(TableObject, Properties);
			TableObject.MetadataObjectKey = New ValueStorage(Properties.MetadataObjectKey);
			TableObject.DataExchange.Load = True;
			CheckObjectsBeforeWriting(TableObject, True);
			TableObject.Write();
		EndDo;
		
		If ValueIsFilled(CriticalChangesList) Then
			WriteLogEvent(
				NStr("en = 'Metadata objects IDs.Critical changes are executed'",
					CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Information,
				,
				,
				CriticalChangesList,
				EventLogEntryTransactionMode.Transactional);
		EndIf;
		
		PrepareNewSubsystemsList(Exporting);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If SwitchOffSoleMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If Not CheckOnly AND Not CommonUseReUse.DataSeparationEnabled() Then
		LaunchParameterClient = SessionParameters.ClientParametersOnServer.Get("LaunchParameter");
		If Find(Lower(LaunchParameterClient), Lower("RegisterFullUpdateIOMForDescendantsOfRIB")) > 0 Then
			RegisterFullUpdateForDescendantsOfRIB();
		EndIf;
	EndIf;
	
	If SwitchOffSoleMode Then
		SetExclusiveMode(False);
	EndIf;
	
	If Not CheckOnly Or Not IsCurrentChanges Then
		StandardSubsystemsServer.ConfirmUpdatingApplicationWorkParameter(
			"BasicFunctionalityParameters", "MetadataObjectIDs");
	EndIf;
	
EndProcedure

// Returns catalog attributes which form
//  the natural key for the catalog items.
//
// Return value: Array(Row) - is the array
//  of names of attributes which form the natural key.
//
Function NaturalKeyFields() Export
	
	Result = New Array();
	
	Result.Add("FullName");
	
	Return Result;
	
EndFunction

// Only for internal use.
//
// Parameters:
//  Objects - Array - values
//            of the CatalogObject.MetadataObjectsIDs type that are required to be imported.
//
Procedure ImportDataToSubordinateNode(Objects) Export
	
	CheckUse();
	
	If CommonUseReUse.DataSeparationEnabled() Then
		// It is not supported in the service model.
		Return;
	EndIf;
	
	If Not CommonUse.IsSubordinateDIBNode() Then
		Return;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.MetadataObjectIDs");
	LockItem.Mode = DataLockMode.Exclusive;
	
	SwitchOffSoleMode = False;
	BeginTransaction();
	Try
		Block.Lock();
		
		// Prepare the source table considering renaming for the duplicates search.
		Exporting = ExportAllIDs();
		Exporting.Columns.Add("DuplicateUpdated", New TypeDescription("Boolean"));
		Exporting.Columns.Add("FullNameLowRegister", New TypeDescription("String"));
		
		// Filter only those objects from the imported ones that differ from the existing ones.
		ImportedTable = New ValueTable;
		ImportedTable.Columns.Add("Object");
		ImportedTable.Columns.Add("Ref");
		ImportedTable.Columns.Add("MetadataObjectByKey");
		ImportedTable.Columns.Add("MetadataObjectByDescriptionFull");
		ImportedTable.Columns.Add("Matches", New TypeDescription("Boolean"));
		
		For Each Object IN Objects Do
			ImportedProperty = ImportedTable.Add();
			ImportedProperty.Object = Object;
			
			If ValueIsFilled(Object.Ref) Then
				ImportedProperty.Ref = Object.Ref;
			Else
				ImportedProperty.Ref = Object.GetNewObjectRef();
				If Not ValueIsFilled(ImportedProperty.Ref) Then
					Raise StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en = 'An error occurred while importing metadata objects IDs.
						           |Unable to import new item in which ref of
						           |a new one is not specified: ""%1"".'"),
						Object.FullName);
				EndIf;
			EndIf;
			
			// Preliminary data processor.
			
			If Not IsCollection(ImportedProperty.Ref) Then
				ImportedProperty.MetadataObjectByKey = MetadataObjectByKey(
					Object.MetadataObjectKey.Get());
				
				ImportedProperty.MetadataObjectByDescriptionFull =
					MetadataFindByFullName(Object.FullName);
				
				If ImportedProperty.MetadataObjectByKey = Undefined
				   AND ImportedProperty.MetadataObjectByDescriptionFull = Undefined
				   AND Object.DeletionMark <> True Then
					// If for some reason imported object is not found
					// in metadata, it should be put for deletion.
					Object.DeletionMark = True;
				EndIf;
			EndIf;
			
			If Object.DeletionMark Then
				// Incorrect full name is invalid for once
				// marked for deletion, that is why to reliably
				// ensure this condition, the procedure of updating the properties of the one marked additionally is applied before importing.
				RefreshPropertiesMarkedForDelete(Object);
			EndIf;
			
			Properties = Exporting.Find(ImportedProperty.Ref, "Ref");
			If Properties <> Undefined
			   AND Properties.Description              = Object.Description
			   AND Properties.Parent                  = Object.Parent
			   AND Properties.CollectionOrder          = Object.CollectionOrder
			   AND Properties.Name                       = Object.Name
			   AND Properties.Synonym                   = Object.Synonym
			   AND Properties.FullName                 = Object.FullName
			   AND Properties.FullSynonym             = Object.FullSynonym
			   AND Properties.WithoutData                 = Object.WithoutData
			   AND Properties.EmptyRefValue      = Object.EmptyRefValue
			   AND Properties.PredefinedDataName = Object.PredefinedDataName
			   AND Properties.DeletionMark           = Object.DeletionMark
			   AND MetadataObjectsKeysNotMatch(Properties, Object) Then
			
				ImportedProperty.Matches = True;
			EndIf;
			
			If Properties <> Undefined Then
				Exporting.Delete(Properties); // Imported ones should not be renamed.
			EndIf;
		EndDo;
		ImportedTable.Indexes.Add("Ref");
		
		// Rename existing items (without imported) for duplicates search.
		
		RenameDescriptionFulls(Exporting);
		For Each String IN Exporting Do
			String.FullNameLowRegister = Lower(String.FullName);
		EndDo;
		Exporting.Indexes.Add("MetadataObjectKey");
		Exporting.Indexes.Add("FullNameLowRegister");
		
		// Prepare imported objects and duplicates in the existing ones.
		
		ObjectsForWrite = New Array;
		DescriptionFullsImported = New Map;
		ImportedKeys = New Map;
		
		For Each ImportedProperty IN ImportedTable Do
			Object = ImportedProperty.Object;
			Ref = ImportedProperty.Ref;
			
			If ImportedProperty.Matches Then
				Continue; // Matching objects do not need to be import.
			EndIf;
			
			If IsCollection(Ref) Then
				ObjectsForWrite.Add(Object);
				Continue;
			EndIf;
			
			// Check whether there are no duplicates among the imported items.
			
			If DescriptionFullsImported.Get(Lower(Object.FullName)) <> Undefined Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'An error occurred while importing metadata objects IDs.
					           |Unable to import two items in which full
					           |name matches: ""%1"".'"),
					Object.FullName);
			EndIf;
			DescriptionFullsImported.Insert(Lower(Object.FullName));
			
			MetadataObjectKey = Object.MetadataObjectKey.Get();
			If TypeOf(MetadataObjectKey) = Type("Type")
			   AND MetadataObjectKey <> Type("Undefined") Then
				
				If ImportedKeys.Get(MetadataObjectKey) <> Undefined Then
					Raise StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en = 'An error occurred while importing metadata objects IDs.
						           |Unable to import two items in which metadata object
						           |key matches: ""%1"".'"),
						String(MetadataObjectKey));
				EndIf;
				ImportedKeys.Insert(MetadataObjectKey);
				
				If ImportedProperty.MetadataObjectByKey <> ImportedProperty.MetadataObjectByDescriptionFull Then
					Raise StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en = 'An error occurred while importing metadata objects IDs.
						           |Unable to import item metadata object of
						           |which  ""%1"" does not correspond to the full name ""%2"".'"),
						String(MetadataObjectKey), Object.FullName);
				EndIf;
				
				If Not Object.DeletionMark Then
					// Determine duplicates among the existing metadata objects by key.
					Rows = Exporting.FindRows(New Structure("MetadataObjectKey", MetadataObjectKey));
					For Each String IN Rows Do
						
						If String.Ref <> Ref
						   AND ImportedTable.Find(String.Ref, "Ref") = Undefined Then
							
							RefreshPropertiesMarkedForDelete(String);
							String.NewRef = Ref;
							String.DuplicateUpdated = True;
							// Replace new references to a duplicate to a new reference specified for a duplicate (if any).
							OldDuplicates = Exporting.FindRows(New Structure("NewRef", String.Ref));
							For Each OldDuplicate IN OldDuplicates Do
								RefreshPropertiesMarkedForDelete(OldDuplicate);
								OldDuplicate.NewRef = Ref;
							EndDo;
						EndIf;
					EndDo;
				EndIf;
			EndIf;
			
			If Not Object.DeletionMark Then
				// Determine duplicates among the existing metadata objects by the full name.
				Rows = Exporting.FindRows(New Structure("FullNameLowRegister", Lower(Object.FullName)));
				For Each String IN Rows Do
					
					If String.Ref <> Ref
					   AND ImportedTable.Find(String.Ref, "Ref") = Undefined Then
					
						RefreshPropertiesMarkedForDelete(String);
						String.NewRef = Ref;
						String.DuplicateUpdated = True;
						// Replace new references to a duplicate to a new reference specified for a duplicate (if any).
						OldDuplicates = Exporting.FindRows(New Structure("NewRef", String.Ref));
						For Each OldDuplicate IN OldDuplicates Do
							RefreshPropertiesMarkedForDelete(OldDuplicate);
							OldDuplicate.NewRef = Ref;
						EndDo;
					EndIf;
				EndDo;
			EndIf;
			
			ObjectsForWrite.Add(Object);
		EndDo;
		
		// Update duplicates.
		Rows = Exporting.FindRows(New Structure("DuplicateUpdated", True));
		For Each Properties IN Rows Do
			ObjectShot = Properties.Ref.GetObject();
			FillPropertyValues(ObjectShot, Properties);
			ObjectShot.MetadataObjectKey = New ValueStorage(Properties.MetadataObjectKey);
			ObjectShot.DataExchange.Load = True;
			ObjectShot.Write();
		EndDo;
		
		// Import objects.
		For Each Object IN ObjectsForWrite Do
			Object.DataExchange.Load = True;
			Object.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Only for internal use.
Procedure CheckUse() Export
	
	If StandardSubsystemsReUse.DisableCatalogMetadataObjectIDs() Then
		Raise
			NStr("en = '""Metadata objects IDs"" catalog is not used.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	If StandardSubsystemsServer.ExchangePlansManager().MasterNode() = Undefined
	   AND ValueIsFilled(CommonUse.ObjectManagerByFullName("Constant.MasterNode").Get()) Then
		
		Raise
			NStr("en = '""Metadata objects IDs"" catalog can not be
			           |used in the infobase with the unconfirmed cancellation of the main node.
			           |
			           |To restore the connection with the main node,
			           |run 1C:Enterprise and click the Restore button or
			           |applicationmatically set the main node saved in the Main node constant.
			           |
			           |To confirm that you want to cancel connection with
			           |the main node, run 1C:Enterprise and click the Disable button or applicationmatically clear the Main node constant.'");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Only for internal use.
Function MetadataObjectKeyCorrespondsDescriptionFull(CurIDProperties) Export
	
	CheckResult = New Structure;
	CheckResult.Insert("NotCorresponds", True);
	CheckResult.Insert("MetadataObjectKey", Undefined);
	
	MetadataObjectKey = CurIDProperties.MetadataObjectKey.Get();
	
	If MetadataObjectKey <> Undefined
	   AND MetadataObjectKey <> Type("Undefined") Then
		// Key is specified, search metadata object by key.
		CheckResult.Insert("MetadataObjectKey", MetadataObjectKey);
		MetadataObject = MetadataObjectByKey(MetadataObjectKey);
		If MetadataObject <> Undefined Then
			CheckResult.NotCorresponds = MetadataObject.FullName() <> CurIDProperties.FullName;
		EndIf;
	Else
		// Key is not specified, search metadata object by the full name.
		MetadataObject = MetadataFindByFullName(CurIDProperties.FullName);
		If MetadataObject = Undefined Then
			// Collection may have been specified
			
			String = StandardSubsystemsReUse.MetadataObjectCollectionProperties().Find(
				CurIDProperties.Ref, "CollectionID");
			
			If String <> Undefined Then
				MetadataObject = Metadata[String.Name];
				CheckResult.NotCorresponds = String.Name <> CurIDProperties.FullName;
			EndIf;
		Else
			CheckResult.NotCorresponds = False;
		EndIf;
	EndIf;
	
	CheckResult.Insert("MetadataObject", MetadataObject);
	
	Return CheckResult;
	
EndFunction

// Only for internal use.
// FullName in the object should be set and set correctly.
//
Procedure UpdateIdentificatorProperty(Object) Export
	
	FullName = Object.FullName;
	
	// Restore old values.
	If ValueIsFilled(Object.Ref) Then
		OldValues = CommonUse.ObjectAttributesValues(
			Object.Ref,
			"Name,
			|CollectionOrder,
			|Name,
			|FullName,
			|Synonym,
			|FullSynonym,
			|WithoutData,
			|EmptyRefValue,
			|MetadataObjectKey");
		FillPropertyValues(Object, OldValues);
	EndIf;
	
	MetadataObject = MetadataFindByFullName(FullName);
	
	If MetadataObject = Undefined Then
		Object.DeletionMark       = True;
		Object.Parent              = EmptyRef();
		Object.Description          = InsertQuestionMark(Object.Description);
		Object.Name                   = InsertQuestionMark(Object.Name);
		Object.Synonym               = InsertQuestionMark(Object.Synonym);
		Object.FullName             = InsertQuestionMark(Object.FullName);
		Object.FullSynonym         = InsertQuestionMark(Object.FullSynonym);
		Object.EmptyRefValue  = Undefined;
		
		If TypeOf(Object) <> Type("FormDataStructure") Then
			Object.MetadataObjectKey = Undefined;
		EndIf;
	Else
		Object.DeletionMark = False;
		
		FullName = MetadataObject.FullName();
		DotPosition = Find(FullName, ".");
		BaseTypeName = Left(FullName, DotPosition -1);
		
		CollectionProperties = StandardSubsystemsReUse.MetadataObjectCollectionProperties();
		Filter = New Structure("SingularName", BaseTypeName);
		Rows = CollectionProperties.FindRows(Filter);
		
		MetadataObjectProperties = MetadataObjectProperties(CollectionProperties.Copy(Rows));
		PropertiesOfObject = MetadataObjectProperties.Find(FullName, "FullName");
		
		FillPropertyValues(Object, PropertiesOfObject);
		
		If TypeOf(Object) <> Type("FormDataStructure") Then
			MetadataObjectKey = Object.MetadataObjectKey.Get();
			If MetadataObjectKey = Undefined
			 OR PropertiesOfObject.WithoutMetadataObjectKey
			     AND MetadataObjectKey <> Type("Undefined") Then
				
				Object.MetadataObjectKey = New ValueStorage(MetadataObjectKey(PropertiesOfObject.FullName));
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Only for internal use.
Function FullNameChangeIsProhibited(Object) Export
	
	If IsCollection(Object.Ref) Then
		Return True;
	EndIf;
	
	DotPosition = Find(Object.FullName, ".");
	BaseTypeName = Left(Object.FullName, DotPosition -1);
	
	Collection_sProperties = StandardSubsystemsReUse.MetadataObjectCollectionProperties(
		).Find(BaseTypeName, "SingularName");
	
	If Collection_sProperties <> Undefined
	   AND Not Collection_sProperties.WithoutMetadataObjectKey Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Only for internal use.
Function RenamingTableForCurrentVersion() Export
	
	RenamingTable = New ValueTable;
	RenamingTable.Columns.Add("LibraryOrder", New TypeDescription("Number"));
	RenamingTable.Columns.Add("VersionPart1",      New TypeDescription("Number"));
	RenamingTable.Columns.Add("VersionPart2",      New TypeDescription("Number"));
	RenamingTable.Columns.Add("VersionPart3",      New TypeDescription("Number"));
	RenamingTable.Columns.Add("VersionPart4",      New TypeDescription("Number"));
	RenamingTable.Columns.Add("AddingOrder", New TypeDescription("Number"));
	RenamingTable.Columns.Add("FormerFullName",   New TypeDescription("String"));
	RenamingTable.Columns.Add("NewFullName",    New TypeDescription("String"));
	
	CollectionWithoutKey = New Map;
	
	Filter = New Structure("WithoutMetadataObjectKey", True);
	
	CollectionWithoutMetadataObjectKey =
		StandardSubsystemsReUse.MetadataObjectCollectionProperties().FindRows(Filter);
	
	For Each String IN CollectionWithoutMetadataObjectKey Do
		CollectionWithoutKey.Insert(Upper(String.SingularName), String.SingularName);
	EndDo;
	
	Total = New Structure;
	Total.Insert("Table", RenamingTable);
	Total.Insert("CollectionWithoutKey", CollectionWithoutKey);
	Total.Insert("LibrariesVersion",  New Map);
	Total.Insert("LibrariesLevel", New Map);
	
	CommonUseOverridable.OnAddMetadataObjectsRenaming(Total);
	CommonUseOverridable.FillTableMetadataObjectsRenaming(Total);
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnAddMetadataObjectsRenaming");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnAddMetadataObjectsRenaming(Total);
	EndDo;
	
	RenamingTable.Sort(
		"LibraryOrder ASC,
   |VersionPart1 ASC,
   |VersionPart2 ASC,
   |VersionPart3 ASC,
   |VersionPart4 ASC,
   |AddingOrder ASC");
	
	Return RenamingTable;
	
EndFunction

// Only for internal use.
Function MetadataObjectCollectionProperties() Export
	
	MetadataObjectCollectionProperties = New ValueTable;
	MetadataObjectCollectionProperties.Columns.Add("Name",                       New TypeDescription("String",, New StringQualifiers(50)));
	MetadataObjectCollectionProperties.Columns.Add("SingularName",               New TypeDescription("String",, New StringQualifiers(50)));
	MetadataObjectCollectionProperties.Columns.Add("Synonym",                   New TypeDescription("String",, New StringQualifiers(255)));
	MetadataObjectCollectionProperties.Columns.Add("SynonymInSingularNumber",           New TypeDescription("String",, New StringQualifiers(255)));
	MetadataObjectCollectionProperties.Columns.Add("CollectionOrder",          New TypeDescription("Number"));
	MetadataObjectCollectionProperties.Columns.Add("WithoutData",                 New TypeDescription("Boolean"));
	MetadataObjectCollectionProperties.Columns.Add("WithoutMetadataObjectKey", New TypeDescription("Boolean"));
	MetadataObjectCollectionProperties.Columns.Add("CollectionID",    New TypeDescription("CatalogRef.MetadataObjectIDs"));
	MetadataObjectCollectionProperties.Columns.Add("ID",             New TypeDescription("String",, New StringQualifiers(36)));
	
	// Constants
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "627a6fb8-872a-11e3-bb87-005056c00008";
	String.Name             = "Constants";
	String.Synonym         = NStr("en = 'Constants'");
	String.SingularName     = "Constant";
	String.SynonymInSingularNumber = NStr("en = 'Constant'");
	
	// Subsystems
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "cdf5ac50-08e8-46af-9a80-4e63fd4a88ff";
	String.Name             = "Subsystems";
	String.Synonym         = NStr("en = 'Subsystems'");
	String.SingularName     = "Subsystem";
	String.SynonymInSingularNumber = NStr("en = 'Subsystem'");
	String.WithoutData       = True;
	String.WithoutMetadataObjectKey = True;
	
	// Roles
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "115c4f55-9c20-4e86-a6d0-d0167ec053a1";
	String.Name             = "Roles";
	String.Synonym         = NStr("en = 'Roles'");
	String.SingularName     = "Role";
	String.SynonymInSingularNumber = NStr("en = 'Role'");
	String.WithoutData       = True;
	String.WithoutMetadataObjectKey = True;
	
	// ExchangePlans
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "269651e0-4b06-4f9d-aaab-a8d2b6bc6077";
	String.Name             = "ExchangePlans";
	String.Synonym         = NStr("en = 'Exchange plans'");
	String.SingularName     = "ExchangePlan";
	String.SynonymInSingularNumber = NStr("en = 'Exchange plan'");
	
	// Catalogs
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "ede89702-30f5-4a2a-8e81-c3a823b7e161";
	String.Name             = "Catalogs";
	String.Synonym         = NStr("en = 'Catalogs'");
	String.SingularName     = "Catalog";
	String.SynonymInSingularNumber = NStr("en = 'Catalog'");
	
	// Documents
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "96c6ab56-0375-40d5-99a2-b83efa3dac8b";
	String.Name             = "Documents";
	String.Synonym         = NStr("en = 'Documents'");
	String.SingularName     = "Document";
	String.SynonymInSingularNumber = NStr("en = 'Document'");
	
	// DocumentJournals
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "07938234-e29b-4cff-961a-9af07a4c6185";
	String.Name             = "DocumentJournals";
	String.Synonym         = NStr("en = 'Document journals'");
	String.SingularName     = "DocumentJournal";
	String.SynonymInSingularNumber = NStr("en = 'Documents journal'");
	String.WithoutData       = True;
	
	// Reports
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "706cf832-0ae5-45b5-8a4a-1f251d054f3b";
	String.Name             = "Reports";
	String.Synonym         = NStr("en = 'Reports'");
	String.SingularName     = "Report";
	String.SynonymInSingularNumber = NStr("en = 'Report'");
	String.WithoutData       = True;
	
	// DataProcessors
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "ae480426-487e-40b2-98ba-d207777449f3";
	String.Name             = "DataProcessors";
	String.Synonym         = NStr("en = 'DataProcessors'");
	String.SingularName     = "DataProcessor";
	String.SynonymInSingularNumber = NStr("en = 'DataProcessor'");
	String.WithoutData       = True;
	
	// ChartsOfCharacteristicTypes
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "8b5649b9-cdd1-4698-9aac-12ba146835c4";
	String.Name             = "ChartsOfCharacteristicTypes";
	String.Synonym         = NStr("en = 'Charts of characteristics types'");
	String.SingularName     = "ChartOfCharacteristicTypes";
	String.SynonymInSingularNumber = NStr("en = 'Chart of characteristic types'");
	
	// ChartsOfAccounts
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "4295af27-543f-4373-bcfc-c0ace9b7620c";
	String.Name             = "ChartsOfAccounts";
	String.Synonym         = NStr("en = 'Charts of accounts'");
	String.SingularName     = "ChartOfAccounts";
	String.SynonymInSingularNumber = NStr("en = 'Chart of accounts'");
	
	// ChartsOfCalculationTypes
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "fca3e7e1-1bf1-49c8-9921-aafb4e787c75";
	String.Name             = "ChartsOfCalculationTypes";
	String.Synonym         = NStr("en = 'Charts of calculation types'");
	String.SingularName     = "ChartOfCalculationTypes";
	String.SynonymInSingularNumber = NStr("en = 'Chart of calculation types'");
	
	// InformationRegisters
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "d7ecc1e9-c068-44dd-83c2-1323ec52dbbb";
	String.Name             = "InformationRegisters";
	String.Synonym         = NStr("en = 'Information registers'");
	String.SingularName     = "InformationRegister";
	String.SynonymInSingularNumber = NStr("en = 'Information register'");
	
	// AccumulationRegisters
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "74083488-b01e-4441-84a6-c386ce88cdb5";
	String.Name             = "AccumulationRegisters";
	String.Synonym         = NStr("en = 'Accumulation registers'");
	String.SingularName     = "AccumulationRegister";
	String.SynonymInSingularNumber = NStr("en = 'Accumulation register'");
	
	// AccountingRegisters
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "9a0d75ff-0eda-454e-b2b7-d2412ffdff18";
	String.Name             = "AccountingRegisters";
	String.Synonym         = NStr("en = 'Accounting registers'");
	String.SingularName     = "AccountingRegister";
	String.SynonymInSingularNumber = NStr("en = 'Accounting register'");
	
	// CalculationRegisters
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "f330686a-0acf-4e26-9cda-108f1404687d";
	String.Name             = "CalculationRegisters";
	String.Synonym         = NStr("en = 'Calculation registers'");
	String.SingularName     = "CalculationRegister";
	String.SynonymInSingularNumber = NStr("en = 'Calculation register'");
	
	// BusinessProcesses
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "a8cdd0e0-c27f-4bf0-9718-10ec054dc468";
	String.Name             = "BusinessProcesses";
	String.Synonym         = NStr("en = 'Business-processes'");
	String.SingularName     = "BusinessProcess";
	String.SynonymInSingularNumber = NStr("en = 'Business-process'");
	
	// Tasks
	String = MetadataObjectCollectionProperties.Add();
	String.ID   = "8d9153ad-7cea-4e25-9542-a557ee59fd16";
	String.Name             = "Tasks";
	String.Synonym         = NStr("en = 'Tasks'");
	String.SingularName     = "Task";
	String.SynonymInSingularNumber = NStr("en = 'Task'");
	
	For Each String IN MetadataObjectCollectionProperties Do
		String.CollectionOrder       = MetadataObjectCollectionProperties.IndexOf(String);
		String.CollectionID = GetRef(New UUID(String.ID));
	EndDo;
	
	MetadataObjectCollectionProperties.Indexes.Add("CollectionID");
	
	Return MetadataObjectCollectionProperties;
	
EndFunction

// Only for internal use.
Procedure CheckObjectsBeforeWriting(Object, AutoUpdate = False) Export
	
	If Not AutoUpdate Then
		
		If Object.IsNew() Then
			
			CallExceptionByError(StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'It is possible to
				           |create new metadata object ID only automatically while updating catalog data.'"),
				Object.FullName));
				
		ElsIf FullNameChangeIsProhibited(Object) Then
			
			CallExceptionByError(StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'While changing metadata object ID
				           |full name ""%1"" was specified that
				           |can be set only automatically while updating catalog data.'"),
				Object.FullName));
		
		ElsIf FullNameIsUsed(Object.FullName, Object.Ref) Then
			
			CallExceptionByError(StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'While changing metadada object ID
				           |full name is
				           |specified ""%1"" that is used in the catalog.'"),
				Object.FullName));
		
		EndIf;
		
		UpdateIdentificatorProperty(Object);
	EndIf;
	
	If CommonUse.IsSubordinateDIBNode() Then
		
		If Object.IsNew()
		   AND Not IsCollection(Object.GetNewObjectRef()) Then
			
			CallExceptionByError(
				NStr("en = 'You can add new items
				           |only in the main node of the distributed infobase.'"));
		EndIf;
		
		If Not Object.DeletionMark
		   AND Not IsCollection(Object.Ref) Then
			
			If Upper(Object.FullName) <> Upper(CommonUse.ObjectAttributeValue(Object.Ref, "FullName")) Then
				CallExceptionByError(
					NStr("en = 'It is possible to change ""Full
					           |name"" attribute only in the main node of the distributed infobase.'"));
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure CallExceptionByError(ErrorText) Export
	
	Raise
		NStr("en = 'An error occurred while working with ""Metadata objects IDs"" catalog.'") + "
		           |
		           |" + ErrorText;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

Function ExportAllIDs()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDs.Ref,
	|	IDs.PredefinedDataName AS PredefinedDataName,
	|	IDs.Parent,
	|	IDs.DeletionMark,
	|	IDs.Description,
	|	IDs.CollectionOrder,
	|	IDs.Name,
	|	IDs.Synonym,
	|	IDs.FullName,
	|	IDs.FullSynonym,
	|	IDs.WithoutData,
	|	IDs.EmptyRefValue,
	|	IDs.MetadataObjectKey AS KeyStorage,
	|	IDs.NewRef
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs";
	Exporting = Query.Execute().Unload();
	Exporting.Columns.Add("MetadataObjectKey");
	Exporting.Columns.Add("WithoutMetadataObjectKey", New TypeDescription("Boolean"));
	Exporting.Columns.Add("IsCollection",              New TypeDescription("Boolean"));
	Exporting.Columns.Add("IsNew",                  New TypeDescription("Boolean"));
	
	// Order IDs before data processor.
	For Each String IN Exporting Do
		If TypeOf(String.KeyStorage) = Type("ValueStorage") Then
			String.MetadataObjectKey = String.KeyStorage.Get();
		Else
			String.MetadataObjectKey = Undefined;
		EndIf;
		
		String.WithoutMetadataObjectKey = String.MetadataObjectKey = Undefined
		                               OR String.MetadataObjectKey = Type("Undefined");
	EndDo;
	
	Exporting.Indexes.Add("Ref");
	Exporting.Indexes.Add("FullName");
	
	CollectionProperties = StandardSubsystemsReUse.MetadataObjectCollectionProperties();
	
	For Each Collection_sProperties IN CollectionProperties Do
		String = Exporting.Find(Collection_sProperties.CollectionID, "Ref");
		If String = Undefined Then
			String = Exporting.Add();
			String.Ref   = Collection_sProperties.CollectionID;
			String.IsNew = True;
		EndIf;
		String.IsCollection = True;
	EndDo;
	
	Exporting.Sort("IsCollection DESC,
	              |DeletionMark ASC,
	              |WithoutMetadataObjectKey ASC");
	
	Return Exporting;
	
EndFunction

Procedure RenameDescriptionFulls(Exporting)
	
	RenamingTable = RenamingTableForCurrentVersion();
	
	For Each RenamingDescription IN RenamingTable Do
		LengthOfFormerFullName = StrLen(RenamingDescription.FormerFullName);
		ThisSubsystem = Upper(Left(RenamingDescription.FormerFullName, 11)) = Upper("Subsystem.");
		
		For Each String IN Exporting Do
			
			If String.IsCollection Then
				Continue;
			EndIf;
			
			If ThisSubsystem Then
				If Upper(Left(String.FullName, LengthOfFormerFullName))
				     = Upper(RenamingDescription.FormerFullName) Then
					
					String.FullName = RenamingDescription.NewFullName
						+ Mid(String.FullName, LengthOfFormerFullName + 1);
				EndIf;
			Else
				If Upper(String.FullName) = Upper(RenamingDescription.FormerFullName) Then
					String.FullName = RenamingDescription.NewFullName;
				EndIf;
			EndIf;
			
		EndDo;
	EndDo;
	
EndProcedure

Procedure RefreshPropertiesMarkedForDelete(Properties, PropertiesUpdated = False, HasDeleted = False)
	
	If TypeOf(Properties.MetadataObjectKey) = Type("ValueStorage") Then
		MetadataObjectKey = Properties.MetadataObjectKey.Get();
	Else
		MetadataObjectKey = Properties.MetadataObjectKey;
	EndIf;
	
	If Not Properties.DeletionMark
	 OR ValueIsFilled(Properties.Parent)
	 OR Left(Properties.Description, 1)  <> "?"
	 OR Left(Properties.Name, 1)           <> "?"
	 OR Left(Properties.Synonym, 1)       <> "?"
	 OR Left(Properties.FullName, 1)     <> "?"
	 OR Left(Properties.FullSynonym, 1) <> "?"
	 OR Find(Properties.FullName, "(") = 0
	 OR Properties.EmptyRefValue  <> Undefined
	 OR MetadataObjectKey <> Undefined Then
		
		If Not Properties.DeletionMark Or Left(Properties.FullName, 1) <> "?" Then
			HasDeleted = True;
		EndIf;
		
		// Set new properties of the metadata object ID.
		Properties.DeletionMark       = True;
		Properties.Parent              = EmptyRef();
		Properties.Description          = InsertQuestionMark(Properties.Description);
		Properties.Name                   = InsertQuestionMark(Properties.Name);
		Properties.Synonym               = InsertQuestionMark(Properties.Synonym);
		Properties.FullName             = UniqueFullName(Properties);
		Properties.FullSynonym         = InsertQuestionMark(Properties.FullSynonym);
		Properties.EmptyRefValue  = Undefined;
		If TypeOf(Properties.MetadataObjectKey) = Type("ValueStorage") Then
			Properties.MetadataObjectKey = New ValueStorage(Undefined);
		Else
			Properties.MetadataObjectKey = Undefined;
		EndIf;
		PropertiesUpdated = True;
	EndIf;
	
EndProcedure

Procedure CheckUpdateCollectionProperties(Val CurrentProperties)
	
	NewProperties = StandardSubsystemsReUse.MetadataObjectCollectionProperties(
		).Find(CurrentProperties.Ref, "CollectionID");
	
	CollectionDescription = NewProperties.Synonym;
	
	If CurrentProperties.Description              <> CollectionDescription
	 OR CurrentProperties.CollectionOrder          <> NewProperties.CollectionOrder
	 OR CurrentProperties.Name                       <> NewProperties.Name
	 OR CurrentProperties.Synonym                   <> NewProperties.Synonym
	 OR CurrentProperties.FullName                 <> NewProperties.Name
	 OR CurrentProperties.FullSynonym             <> NewProperties.Synonym
	 OR CurrentProperties.WithoutData                 <> False
	 OR CurrentProperties.EmptyRefValue      <> Undefined
	 OR CurrentProperties.PredefinedDataName <> ""
	 OR CurrentProperties.DeletionMark           <> False
	 OR CurrentProperties.MetadataObjectKey     <> Undefined Then
		
		// Installation of new properties.
		CurrentProperties.Description              = CollectionDescription;
		CurrentProperties.CollectionOrder          = NewProperties.CollectionOrder;
		CurrentProperties.Name                       = NewProperties.Name;
		CurrentProperties.Synonym                   = NewProperties.Synonym;
		CurrentProperties.FullName                 = NewProperties.Name;
		CurrentProperties.FullSynonym             = NewProperties.Synonym;
		CurrentProperties.WithoutData                 = False;
		CurrentProperties.EmptyRefValue      = Undefined;
		CurrentProperties.PredefinedDataName = "";
		CurrentProperties.DeletionMark           = False;
		CurrentProperties.MetadataObjectKey     = Undefined;
		
		CurrentProperties.Updated = True;
	EndIf;
	
EndProcedure

Function MetadataObjectKey(FullName)
	
	DotPosition = Find(FullName, ".");
	
	MOClass = Left( FullName, DotPosition-1);
	MOName   = Mid(FullName, DotPosition+1);
	
	If Upper(MOClass) = Upper("ExchangePlan") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("Constant") Then
		Return TypeOf(CommonUse.ObjectManagerByFullName(FullName));
		
	ElsIf Upper(MOClass) = Upper("Catalog") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("Document") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("DocumentJournal") Then
		Return TypeOf(CommonUse.ObjectManagerByFullName(FullName));
		
	ElsIf Upper(MOClass) = Upper("Report") Then
		Return Type(MOClass + "Object." + MOName);
		
	ElsIf Upper(MOClass) = Upper("DataProcessor") Then
		Return Type(MOClass + "Object." + MOName);
		
	ElsIf Upper(MOClass) = Upper("ChartOfCharacteristicTypes") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("ChartOfAccounts") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("ChartOfCalculationTypes") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("InformationRegister") Then
		Return Type(MOClass + "RecordKey." + MOName);
		
	ElsIf Upper(MOClass) = Upper("AccumulationRegister") Then
		Return Type(MOClass + "RecordKey." + MOName);
		
	ElsIf Upper(MOClass) = Upper("AccountingRegister") Then
		Return Type(MOClass + "RecordKey." + MOName);
		
	ElsIf Upper(MOClass) = Upper("CalculationRegister") Then
		Return Type(MOClass + "RecordKey." + MOName);
		
	ElsIf Upper(MOClass) = Upper("BusinessProcess") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("Task") Then
		Return Type(MOClass + "Ref." + MOName);
	Else
		// Without metadata object key.
		Return Type("Undefined");
	EndIf;
	
EndFunction 

Function MetadataObjectsKeysNotMatch(Properties, Object)
	
	Return Properties.MetadataObjectKey = Object.MetadataObjectKey.Get();
	
EndFunction

Function MetadataObjectByKey(MetadataObjectKey)
	
	MetadataObject = Undefined;
	
	If TypeOf(MetadataObjectKey) = Type("Type") Then
		MetadataObject = Metadata.FindByType(MetadataObjectKey);
	EndIf;
	
	Return MetadataObject;
	
EndFunction

Function MetadataObjectProperties(CollectionProperties = Undefined)
	
	MetadataObjectProperties = New ValueTable;
	MetadataObjectProperties.Columns.Add("Description",              New TypeDescription("String",, New StringQualifiers(150)));
	MetadataObjectProperties.Columns.Add("FullName",                 New TypeDescription("String",, New StringQualifiers(510)));
	MetadataObjectProperties.Columns.Add("ParentFullName",         New TypeDescription("String",, New StringQualifiers(510)));
	MetadataObjectProperties.Columns.Add("CollectionOrder",          New TypeDescription("Number"));
	MetadataObjectProperties.Columns.Add("Parent",                  New TypeDescription("CatalogRef.MetadataObjectIDs"));
	MetadataObjectProperties.Columns.Add("Name",                       New TypeDescription("String",, New StringQualifiers(150)));
	MetadataObjectProperties.Columns.Add("Synonym",                   New TypeDescription("String",, New StringQualifiers(255)));
	MetadataObjectProperties.Columns.Add("FullSynonym",             New TypeDescription("String",, New StringQualifiers(510)));
	MetadataObjectProperties.Columns.Add("WithoutData",                 New TypeDescription("Boolean"));
	MetadataObjectProperties.Columns.Add("WithoutMetadataObjectKey", New TypeDescription("Boolean"));
	MetadataObjectProperties.Columns.Add("EmptyRefValue");
	MetadataObjectProperties.Columns.Add("MetadataObject");
	
	If CollectionProperties = Undefined Then
		CollectionProperties = StandardSubsystemsReUse.MetadataObjectCollectionProperties();
	EndIf;
	
	For Each Collection_sProperties IN CollectionProperties Do
		AddMetadataObjectProperties(Metadata[Collection_sProperties.Name], Collection_sProperties, MetadataObjectProperties);
	EndDo;
	
	MetadataObjectProperties.Indexes.Add("FullName");
	
	Return MetadataObjectProperties;
	
EndFunction

Procedure AddMetadataObjectProperties(Val MetadataObjectCollection,
                                             Val Collection_sProperties,
                                             Val MetadataObjectProperties,
                                             Val ParentFullName = "",
                                             Val ParentFullSynonym = "")
	
	For Each MetadataObject IN MetadataObjectCollection Do
		
		FullName = MetadataObject.FullName();
		If Find(Collection_sProperties.SingularName, "Subsystem") <> 0 Then
			MetadataFindByFullName(FullName);
		EndIf;
		
		If Not Collection_sProperties.WithoutData
		   AND Find(Collection_sProperties.SingularName, "Register") = 0
		   AND Find(Collection_sProperties.SingularName, "Constant") = 0 Then
			
			EmptyRefValue = CommonUse.ObjectManagerByFullName(FullName).EmptyRef();
		Else
			EmptyRefValue = Undefined;
		EndIf;
		
		NewRow = MetadataObjectProperties.Add();
		FillPropertyValues(NewRow, Collection_sProperties);
		NewRow.Parent          = Collection_sProperties.CollectionID;
		NewRow.Description      = MetadataObjectPresentation(MetadataObject, Collection_sProperties);
		NewRow.FullName         = FullName;
		NewRow.ParentFullName = ParentFullName;
		NewRow.Name               = MetadataObject.Name;
		
		NewRow.Synonym = ?(
			ValueIsFilled(MetadataObject.Synonym), MetadataObject.Synonym, MetadataObject.Name);
		
		NewRow.FullSynonym =
			ParentFullSynonym + Collection_sProperties.SynonymInSingularNumber + ". " + NewRow.Synonym;
		
		NewRow.EmptyRefValue = EmptyRefValue;
		NewRow.MetadataObject     = MetadataObject;
		
		If Collection_sProperties.Name = "Subsystems" Then
			AddMetadataObjectProperties(
				MetadataObject.Subsystems,
				Collection_sProperties,
				MetadataObjectProperties,
				FullName,
				NewRow.FullSynonym + ". ");
		EndIf;
	EndDo;
	
EndProcedure

Function MetadataObjectPresentation(Val MetadataObject, Val Collection_sProperties)
	
	Postfix = "(" + Collection_sProperties.SynonymInSingularNumber + ")";
	
	Synonym = ?(ValueIsFilled(MetadataObject.Synonym), MetadataObject.Synonym, MetadataObject.Name);
	
	SynonymMaxLength = 150 - StrLen(Postfix);
	If StrLen(Synonym) > SynonymMaxLength + 1 Then
		Return Left(Synonym, SynonymMaxLength - 2) + "..." + Postfix;
	EndIf;
	
	Return Synonym + " (" + Collection_sProperties.SynonymInSingularNumber + ")";
	
EndFunction

Function InsertQuestionMark(Val String)
	
	If Left(String, 1) <> "?" Then
		If Left(String, 1) <> " " Then
			String = "? " + String;
		Else
			String = "?" + String;
		EndIf;
	EndIf;
	
	Return String;
	
EndFunction

Function UniqueFullName(Properties)
	
	FullName = InsertQuestionMark(Properties.FullName);
	
	If Find(FullName, "(") = 0 Then
		FullName = FullName + " (" + String(Properties.Ref.UUID())+ ")";
	EndIf;
	
	Return FullName;
	
EndFunction

Function MetadataFindByFullName(FullName)
	
	MetadataObject = Metadata.FindByFullName(FullName);
	
	If MetadataObject = Undefined Then
		Return Undefined;
	EndIf;
	
	If Upper(MetadataObject.FullName()) <> Upper(FullName) Then
		
		If StrOccurrenceCount(Upper(FullName), Upper("Subsystem.")) > 1 Then
			Subsystem = FindSubsystemByDescriptionFull(FullName);
			If Subsystem = Undefined Then
				Return Undefined;
			EndIf;
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'An error occurred while searching for a child subsystem by a full name (while searching ""%1"" was found ""%2"").
				           |Do not give subsystems the same names or use the recent platform version.'"),
				FullName,
				MetadataObject.FullName());
		Else
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'An error occurred while searching for metadata by a full name (while searching ""%1"" was found ""%2"").'"),
				FullName,
				MetadataObject.FullName());
		EndIf;
	EndIf;
	
	Return MetadataObject;
	
EndFunction

Function FindSubsystemByDescriptionFull(FullName, SubsystemCollection = Undefined)
	
	If SubsystemCollection = Undefined Then
		SubsystemCollection = Metadata.Subsystems;
	EndIf;
	
	NameBalance = Mid(FullName, StrLen("Subsystem.") + 1);
	Position = Find(Upper(NameBalance), Upper("Subsystem."));
	If Position > 0 Then
		SubsystemName = Left(NameBalance, Position - 2);
		NameBalance = Mid(FullName, Position + StrLen("Subsystem."));
	Else
		SubsystemName = NameBalance;
		NameBalance = Undefined;
	EndIf;
	
	FoundSubsystem = Undefined;
	For Each Subsystem IN SubsystemCollection Do
		If Upper(Subsystem.Name) = Upper(SubsystemName) Then
			FoundSubsystem = Subsystem;
			Break;
		EndIf;
	EndDo;
	
	If FoundSubsystem = Undefined Then
		Return Undefined;
	EndIf;
	
	If NameBalance = Undefined Then
		Return FoundSubsystem;
	EndIf;
	
	Return FindSubsystemByDescriptionFull(NameBalance, FoundSubsystem.Subsystems);
	
EndFunction

Function FullNameIsUsed(FullName, ExceptIdentificator = Undefined)
	
	Query = New Query;
	Query.SetParameter("FullName", FullName);
	Query.SetParameter("Ref",    ExceptIdentificator);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|WHERE
	|	MetadataObjectIDs.Ref <> &Ref
	|	AND MetadataObjectIDs.FullName = &FullName";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function IsCollection(Ref)
	
	Return StandardSubsystemsReUse.MetadataObjectCollectionProperties(
		).Find(Ref, "CollectionID") <> Undefined;
	
EndFunction

Procedure PrepareNewSubsystemsList(Exporting)
	
	FoundDescription = Exporting.Find(Metadata.Subsystems.StandardSubsystems, "MetadataObject");
	If FoundDescription = Undefined Then
		Return;
	EndIf;
	SubsystemStandardSubsystems = FoundDescription.Ref;
	
	Filter = New Structure;
	Filter.Insert("IsNew", True);
	Filter.Insert("Parent", SubsystemStandardSubsystems);
	
	FoundDescriptions = Exporting.FindRows(Filter);
	
	NewSubsystems = New Array;
	For Each Definition IN FoundDescriptions Do
		NewSubsystems.Add(Definition.FullName);
	EndDo;
	
	DataAboutUpdate = InfobaseUpdateService.DataOnUpdatingInformationBase();
	For Each SubsystemName IN NewSubsystems Do
		If DataAboutUpdate.NewSubsystems.Find(SubsystemName) = Undefined Then
			DataAboutUpdate.NewSubsystems.Add(SubsystemName);
		EndIf;
	EndDo;
	InfobaseUpdateService.WriteDataOnUpdatingInformationBase(DataAboutUpdate);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of ID replacement in the data base.

Procedure ReplaceSubordinateNodeDuplicatesOnImport(CheckOnly, HasChanges)
	
	If CommonUseReUse.DataSeparationEnabled() Then
		// It is not supported in the service model.
		Return;
	EndIf;
	
	If Not CommonUse.IsSubordinateDIBNode() Then
		Return;
	EndIf;
	
	// Replace duplicates in the DIB subordinate node.
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDs.Ref,
	|	IDs.NewRef
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs
	|WHERE
	|	IDs.NewRef <> VALUE(Catalog.MetadataObjectIDs.EmptyRef)";
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	If CheckOnly Then
		HasChanges = True;
		Return;
	EndIf;
	
	If ExclusiveMode() Then
		SwitchOffSoleMode = False;
	Else
		SwitchOffSoleMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	Try
		Selection = QueryResult.Select();
		ReplaceReferences = New Array;
		OldAndNewLinks = New Map;
		While Selection.Next() Do
			ReplaceReferences.Add(Selection.Ref);
			OldAndNewLinks.Insert(Selection.Ref, Selection.NewRef);
		EndDo;
		
		FoundData = FindByRef(ReplaceReferences);
		FoundData.Columns[0].Name = "Ref";
		FoundData.Columns[1].Name = "Data";
		FoundData.Columns[2].Name = "Metadata";
		FoundData.Columns.Add("Enabled");
		FoundData.FillValues(True, "Enabled");
		
		If FoundData.Count() > 0 Then
			BeginTransaction();
			Try
				ExecuteItemReplacement(OldAndNewLinks, FoundData, True);
				
				// Clear new references in IDs duplicates.
				For Each ReplaceReference IN ReplaceReferences Do
					ObjectShot = ReplaceReference.GetObject();
					ObjectShot.NewRef = Undefined;
					ObjectShot.DataExchange.Load = True;
					ObjectShot.Write();
				EndDo;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
		EndIf;
	Except
		If SwitchOffSoleMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If SwitchOffSoleMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

// Function from the SearchAndReplaceDuplicates universal data processor.
// Changes:
// - work with progressor form
// - UserAbortDataProcessor() procedure is deleted
// - InformationRegisters[TableRow.Metadata.Name] replaced with.
//   CommonUse.ObjectManagerByFullName(TableRow.Metadata.FullName())
//
Function ExecuteItemReplacement(Val Replaceable, Val RefsTable, Val DisableWriteControl = False, Val ExecuteTransactioned = False)
	
	Parameters = New Structure;
	
	For Each AccountingRegister IN Metadata.AccountingRegisters Do
		Parameters.Insert(AccountingRegister.Name + "ExtDimension",        AccountingRegister.ChartOfAccounts.MaxExtDimensionCount);
		Parameters.Insert(AccountingRegister.Name + "Correspondence", AccountingRegister.Correspondence);
	EndDo;
	
	Parameters.Insert("Object", Undefined);
	
	RefToProcess = Undefined;
	HasException = False;
		
	If ExecuteTransactioned Then
		BeginTransaction();
	EndIf;
	
	Try
		For Each TableRow IN RefsTable Do
			If Not TableRow.Enabled Then
				Continue;
			EndIf;
			CorrectItem = Replaceable[TableRow.Ref];
			
			Ref = TableRow.Ref;
			
			If RefToProcess <> TableRow.Data Then
				If RefToProcess <> Undefined AND Parameters.Object <> Undefined Then
					
					If DisableWriteControl Then
						Parameters.Object.DataExchange.Load = True;
					EndIf;
					
					Try
						Parameters.Object.Write();
					Except
						HasException = True;
						If ExecuteTransactioned Then
							Raise;
						EndIf;
						ShowMessageAboutError(ErrorInfo());
					EndTry;
					Parameters.Object = Undefined;
				EndIf;
				RefToProcess = TableRow.Data;
			EndIf;
			
			If Metadata.Documents.Contains(TableRow.Metadata) Then
				
				If Parameters.Object = Undefined Then
					Parameters.Object = TableRow.Data.GetObject();
				EndIf;
				
				For Each Attribute IN TableRow.Metadata.Attributes Do
					If Attribute.Type.ContainsType(TypeOf(Ref)) AND Parameters.Object[Attribute.Name] = Ref Then
						Parameters.Object[Attribute.Name] = CorrectItem;
					EndIf;
				EndDo;
					
				For Each TabularSection IN TableRow.Metadata.TabularSections Do
					For Each Attribute IN TabularSection.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							TabularSectionRow = Parameters.Object[TabularSection.Name].Find(Ref, Attribute.Name);
							While TabularSectionRow <> Undefined Do
								TabularSectionRow[Attribute.Name] = CorrectItem;
								TabularSectionRow = Parameters.Object[TabularSection.Name].Find(Ref, Attribute.Name);
							EndDo;
						EndIf;
					EndDo;
				EndDo;
				
				For Each RegisterRecord IN TableRow.Metadata.RegisterRecords Do
					
					IsAccountingRegisterRecord = Metadata.AccountingRegisters.Contains(RegisterRecord);
					HasCorrespondence = IsAccountingRegisterRecord AND Parameters[RegisterRecord.Name + "Correspondence"];
					
					RecordSet = Parameters.Object.RegisterRecords[RegisterRecord.Name];
					RecordSet.Read();
					MustWrite = False;
					SetTable = RecordSet.Unload();
					
					If SetTable.Count() = 0 Then
						Continue;
					EndIf;
					
					ColumnNames = New Array;
					
					// Receive changes names that can contain reference.
					For Each Dimension IN RegisterRecord.Dimensions Do
						
						If Dimension.Type.ContainsType(TypeOf(Ref)) Then
							
							If IsAccountingRegisterRecord Then
								
								If Dimension.AccountingFlag <> Undefined Then
									
									ColumnNames.Add(Dimension.Name + "Dr");
									ColumnNames.Add(Dimension.Name + "Cr");
								Else
									ColumnNames.Add(Dimension.Name);
								EndIf;
							Else
								ColumnNames.Add(Dimension.Name);
							EndIf;
						EndIf;
					EndDo;
					
					// Receive resources names that can contain a reference.
					If Metadata.InformationRegisters.Contains(RegisterRecord) Then
						For Each Resource IN RegisterRecord.Resources Do
							If Resource.Type.ContainsType(TypeOf(Ref)) Then
								ColumnNames.Add(Resource.Name);
							EndIf;
						EndDo;
					EndIf;
					
					// Receive resources names that can contain a reference.
					For Each Attribute IN RegisterRecord.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							ColumnNames.Add(Attribute.Name);
						EndIf;
					EndDo;
					
					// Execute replacements in table.
					For Each ColumnName IN ColumnNames Do
						TabularSectionRow = SetTable.Find(Ref, ColumnName);
						While TabularSectionRow <> Undefined Do
							TabularSectionRow[ColumnName] = CorrectItem;
							MustWrite = True;
							TabularSectionRow = SetTable.Find(Ref, ColumnName);
						EndDo;
					EndDo;
					
					If Metadata.AccountingRegisters.Contains(RegisterRecord) Then
						
						For ExtDimensionIndex = 1 To Parameters[RegisterRecord.Name + "ExtDimension"] Do
							If HasCorrespondence Then
								TabularSectionRow = SetTable.Find(Ref, "ExtDimensionDr"+ExtDimensionIndex);
								While TabularSectionRow <> Undefined Do
									TabularSectionRow["ExtDimensionDr"+ExtDimensionIndex] = CorrectItem;
									MustWrite = True;
									TabularSectionRow = SetTable.Find(Ref, "ExtDimensionDr"+ExtDimensionIndex);
								EndDo;
								TabularSectionRow = SetTable.Find(Ref, "ExtDimensionCr"+ExtDimensionIndex);
								While TabularSectionRow <> Undefined Do
									TabularSectionRow["ExtDimensionCr"+ExtDimensionIndex] = CorrectItem;
									MustWrite = True;
									TabularSectionRow = SetTable.Find(Ref, "ExtDimensionCr"+ExtDimensionIndex);
								EndDo;
							Else
								TabularSectionRow = SetTable.Find(Ref, "ExtDimension"+ExtDimensionIndex);
								While TabularSectionRow <> Undefined Do
									TabularSectionRow["ExtDimension"+ExtDimensionIndex] = CorrectItem;
									MustWrite = True;
									TabularSectionRow = SetTable.Find(Ref, "ExtDimension"+ExtDimensionIndex);
								EndDo;
							EndIf;
						EndDo;
						
						If Ref.Metadata() = RegisterRecord.ChartOfAccounts Then
							For Each TabularSectionRow IN SetTable Do
								If HasCorrespondence Then
									If TabularSectionRow.AccountDr = Ref Then
										TabularSectionRow.AccountDr = CorrectItem;
										MustWrite = True;
									EndIf;
									If TabularSectionRow.AccountCr = Ref Then
										TabularSectionRow.AccountCr = CorrectItem;
										MustWrite = True;
									EndIf;
								Else
									If TabularSectionRow.Account = Ref Then
										TabularSectionRow.Account = CorrectItem;
										MustWrite = True;
									EndIf;
								EndIf;
							EndDo;
						EndIf;
					EndIf;
					
					If Metadata.CalculationRegisters.Contains(RegisterRecord) Then
						TabularSectionRow = SetTable.Find(Ref, "CalculationType");
						While TabularSectionRow <> Undefined Do
							TabularSectionRow["CalculationType"] = CorrectItem;
							MustWrite = True;
							TabularSectionRow = SetTable.Find(Ref, "CalculationType");
						EndDo;
					EndIf;
					
					If MustWrite Then
						RecordSet.Load(SetTable);
						If DisableWriteControl Then
							RecordSet.DataExchange.Load = True;
						EndIf;
						Try
							RecordSet.Write();
						Except
							HasException = True;
							If ExecuteTransactioned Then
								Raise;
							EndIf;
							ShowMessageAboutError(ErrorInfo());
						EndTry;
					EndIf;
				EndDo;
				
				For Each Sequence IN Metadata.Sequences Do
					If Sequence.Documents.Contains(TableRow.Metadata) Then
						MustWrite = False;
						RecordSet = Sequences[Sequence.Name].CreateRecordSet();
						RecordSet.Filter.Recorder.Set(TableRow.Data);
						RecordSet.Read();
						
						If RecordSet.Count() > 0 Then
							For Each Dimension IN Sequence.Dimensions Do
								If Dimension.Type.ContainsType(TypeOf(Ref)) AND RecordSet[0][Dimension.Name]=Ref Then
									RecordSet[0][Dimension.Name] = CorrectItem;
									MustWrite = True;
								EndIf;
							EndDo;
							If MustWrite Then
								If DisableWriteControl Then
									RecordSet.DataExchange.Load = True;
								EndIf;
								Try
									RecordSet.Write();
								Except
									HasException = True;
									If ExecuteTransactioned Then
										Raise;
									EndIf;
									ShowMessageAboutError(ErrorInfo());
								EndTry;
							EndIf;
						EndIf;
					EndIf;
				EndDo;
				
			ElsIf Metadata.Catalogs.Contains(TableRow.Metadata) Then
				
				If Parameters.Object = Undefined Then
					Parameters.Object = TableRow.Data.GetObject();
				EndIf;
				
				If TableRow.Metadata.Owners.Contains(Ref.Metadata()) AND Parameters.Object.Owner = Ref Then
					Parameters.Object.Owner = CorrectItem;
				EndIf;
				
				If TableRow.Metadata.Hierarchical AND Parameters.Object.Parent = Ref Then
					Parameters.Object.Parent = CorrectItem;
				EndIf;
				
				For Each Attribute IN TableRow.Metadata.Attributes Do
					If Attribute.Type.ContainsType(TypeOf(Ref)) AND Parameters.Object[Attribute.Name] = Ref Then
						Parameters.Object[Attribute.Name] = CorrectItem;
					EndIf;
				EndDo;
				
				For Each CWT IN TableRow.Metadata.TabularSections Do
					For Each Attribute IN CWT.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							TabularSectionRow = Parameters.Object[CWT.Name].Find(Ref, Attribute.Name);
							While TabularSectionRow <> Undefined Do
								TabularSectionRow[Attribute.Name] = CorrectItem;
								TabularSectionRow = Parameters.Object[CWT.Name].Find(Ref, Attribute.Name);
							EndDo;
						EndIf;
					EndDo;
				EndDo;
				
			ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(TableRow.Metadata)
			      OR Metadata.ChartsOfAccounts.Contains            (TableRow.Metadata)
			      OR Metadata.ChartsOfCalculationTypes.Contains      (TableRow.Metadata)
			      OR Metadata.Tasks.Contains                 (TableRow.Metadata)
			      OR Metadata.BusinessProcesses.Contains         (TableRow.Metadata) Then
				
				If Parameters.Object = Undefined Then
					Parameters.Object = TableRow.Data.GetObject();
				EndIf;
				
				For Each Attribute IN TableRow.Metadata.Attributes Do
					If Attribute.Type.ContainsType(TypeOf(Ref)) AND Parameters.Object[Attribute.Name] = Ref Then
						Parameters.Object[Attribute.Name] = CorrectItem;
					EndIf;
				EndDo;
				
				For Each CWT IN TableRow.Metadata.TabularSections Do
					For Each Attribute IN CWT.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							TabularSectionRow = Parameters.Object[CWT.Name].Find(Ref, Attribute.Name);
							While TabularSectionRow <> Undefined Do
								TabularSectionRow[Attribute.Name] = CorrectItem;
								TabularSectionRow = Parameters.Object[CWT.Name].Find(Ref, Attribute.Name);
							EndDo;
						EndIf;
					EndDo;
				EndDo;
				
			ElsIf Metadata.Constants.Contains(TableRow.Metadata) Then
				
				CommonUse.ObjectManagerByFullName(
					TableRow.Metadata.FullName()).Set(CorrectItem);
				
			ElsIf Metadata.InformationRegisters.Contains(TableRow.Metadata) Then
				
				DimensionStructure = New Structure;
				RecordSet = CommonUse.ObjectManagerByFullName(TableRow.Metadata.FullName()).CreateRecordSet();
				For Each Dimension IN TableRow.Metadata.Dimensions Do
					RecordSet.Filter[Dimension.Name].Set(TableRow.Data[Dimension.Name]);
					DimensionStructure.Insert(Dimension.Name);
				EndDo;
				If TableRow.Metadata.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
					RecordSet.Filter["Period"].Set(TableRow.Data.Period);
				EndIf;
				RecordSet.Read();
				
				If RecordSet.Count() = 0 Then
					Continue;
				EndIf;
				
				SetTable = RecordSet.Unload();
				RecordSet.Clear();
				
				If DisableWriteControl Then
					RecordSet.DataExchange.Load = True;
				EndIf;
				
				If Not ExecuteTransactioned Then
					BeginTransaction();
				EndIf;
				
				Try
					RecordSet.Write();
					
					For Each Column IN SetTable.Columns Do
						If SetTable[0][Column.Name] = Ref Then
							SetTable[0][Column.Name] = CorrectItem;
							If DimensionStructure.Property(Column.Name) Then
								RecordSet.Filter[Column.Name].Set(CorrectItem);
							EndIf;
							
						EndIf;
					EndDo;
					
					RecordSet.Load(SetTable);
					
					RecordSet.Write();
					
					If Not ExecuteTransactioned Then
						CommitTransaction();
					EndIf;
					
				Except
					HasException = True;
					If ExecuteTransactioned Then
						Raise;
					EndIf;
					RollbackTransaction();
					ShowMessageAboutError(ErrorInfo());
				EndTry;
			Else
				ShowMessageAboutError(NStr("en = 'Values are not replaced in the type data'") + ": " + TableRow.Metadata);
			EndIf;
		EndDo;
	
		If Parameters.Object <> Undefined Then
			If DisableWriteControl Then
				Parameters.Object.DataExchange.Load = True;
			EndIf;
			Try
				Parameters.Object.Write();
			Except
				HasException = True;
				If ExecuteTransactioned Then
					Raise;
				EndIf;
				ShowMessageAboutError(ErrorInfo());
			EndTry;
		EndIf;
		
		If ExecuteTransactioned Then
			CommitTransaction();
		EndIf;
	Except
		HasException = True;
		If ExecuteTransactioned Then
			RollbackTransaction();
		EndIf;
		ShowMessageAboutError(ErrorInfo());
	EndTry;
	
	Return Not HasException;
	
EndFunction

// Procedure from the SearchAndReplaceValues universal data processor.
// Changes:
// - Report(...) method is replaced with EventLogMonitorRecord(...).
//
Procedure ShowMessageAboutError(Val Definition)
	
	If TypeOf(Definition) = Type("ErrorInfo") Then
		Definition = ?(Definition.Cause = Undefined, Definition, Definition.Cause).Definition;
	EndIf;
	
	WriteLogEvent(
		NStr("en = 'Metadata objects IDs. Identifier replacement'",
		     CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Error,
		,
		,
		Definition,
		EventLogEntryTransactionMode.Independent);
	
EndProcedure

#EndRegion

#EndIf