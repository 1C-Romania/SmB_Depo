#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Updates the hierarchy of the objects rights settings owners.
// For example, hierarchy of the FilesFolders catalog items.
//
// Parameters:
//  OwnersOfRightsSettings - Ref, for example, CatalogRef.FilesFolders or
//                          other type according to which the rights are set.
//                        - Type of the rights owner, for example, Type(CatalogRef.FilesFolders).
//                        - Array of the values specified above the types.
//                        - Undefined - without filter for all types.
//                        - Object, for example, CatalogObject.FilesFolders,
//                          when the objects are passed, an update will take
//                          place if an object is before write and it is changed (parent is changed).
//
//  HasChanges         - Boolean (return value) - if there
//                          is a record, True is set, otherwise, it is not changed.
//
Procedure RefreshDataRegister(Val OwnersOfRightsSettings = Undefined, HasChanges = Undefined) Export
	
	If OwnersOfRightsSettings = Undefined Then
		
		PossibleRights = AccessManagementServiceReUse.Parameters(
			).PossibleRightsForObjectRightsSettings;
		
		Query = New Query;
		QueryText =
		"SELECT
		|	CurrentTable.Ref
		|FROM
		|	&CurrentTable AS CurrentTable";
		
		For Each KeyAndValue IN PossibleRights.ByFullNames Do
			
			Query.Text = StrReplace(QueryText, "&CurrentTable", KeyAndValue.Key);
			Selection = Query.Execute().Select();
			
			While Selection.Next() Do
				UpdateOwnerParents(Selection.Ref, HasChanges);
			EndDo;
		EndDo;
		
	ElsIf TypeOf(OwnersOfRightsSettings) = Type("Array") Then
		
		For Each RightSettingsOwner IN OwnersOfRightsSettings Do
			UpdateOwnerParents(RightSettingsOwner, HasChanges);
		EndDo;
	Else
		UpdateOwnerParents(OwnersOfRightsSettings, HasChanges);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Updates the parents of the objects rights settings owners.
// For example, the FilesFolders catalog.
// 
// Parameters:
//  RightSettingsOwner - Ref, for example, CatalogRef.FilesFolders or
//                         other type according to which the rights are set.
//                       - Object, for example, CatalogObject.FilesFolders,
//                         when the objects are passed, an update will take
//                         place if an object is before write and it is changed (parent is changed).
//
//  HasChanges        - Boolean (return value) - if there
//                         is a record, True is set, otherwise, it is not changed.
//
//  UpdateHierarchy     - Boolean - forcefully updates
//                         the inferior hierarchy regardless of the change of the owners parents.
//
//  ObjectsWithChanges  - only for an internal usage.
//
Procedure UpdateOwnerParents(RightSettingsOwner, HasChanges, UpdateHierarchy = False, ObjectsWithChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	PossibleRights = AccessManagementServiceReUse.Parameters().PossibleRightsForObjectRightsSettings;
	OwnerType = TypeOf(RightSettingsOwner);
	
	ErrorTitle =
		NStr("en='An error occurred during update of hierarchy of the rights owners by access values.';ru='Ошибка при обновлении иерархии владельцев прав по значениям доступа.'")
		+ Chars.LF
		+ Chars.LF;
	
	If PossibleRights.ByTypes.Get(OwnerType) = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			ErrorTitle +
			NStr("en='For %1"
"type the usage of objects rights settings is not set.';ru='Для"
"типа ""%1"" не настроено использование настроек прав объектов.'"),
			String(OwnerType));
	EndIf;
	
	If PossibleRights.ByRefsTypes.Get(OwnerType) = Undefined Then
		Refs = AccessManagementService.ObjectRef(RightSettingsOwner);
		Object = RightSettingsOwner;
	Else
		Refs = RightSettingsOwner;
		Object = Undefined;
	EndIf;
	
	Hierarchical = PossibleRights.HierarchicalTables.Get(OwnerType) <> Undefined;
	UpdateNeeded = False;
	
	If Hierarchical Then
		ObjectParentProperties = ParentProperties(Refs);
		
		If Object <> Undefined Then
			// Check object change.
			If ObjectParentProperties.Ref <> Object.Parent Then
				UpdateNeeded = True;
			EndIf;
			ObjectParentProperties.Ref      = Object.Parent;
			ObjectParentProperties.Inherit = SettingsInheritance(Object.Parent);
		Else
			UpdateNeeded = True;
		EndIf;
	Else
		If Object = Undefined Then
			UpdateNeeded = True;
		EndIf;
	EndIf;
	
	If Not UpdateNeeded Then
		Return;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ObjectRightsSettingsInheritance");
	LockItem.Mode = DataLockMode.Exclusive;
	
	If Object = Undefined Then
		AdditionalProperties = Undefined;
	Else
		AdditionalProperties = New Structure("LeadingObjectBeforeWrite", Object);
	EndIf;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		RecordSet = InformationRegisters.ObjectRightsSettingsInheritance.CreateRecordSet();
		RecordSet.Filter.Object.Set(Refs);
		
		// Prepare object parents.
		If Hierarchical Then
			NewRecords = ObjectParents(Refs, Refs, ObjectParentProperties);
		Else
			NewRecords = AccessManagementServiceReUse.EmptyRecordSetTable(
				"InformationRegister.ObjectRightsSettingsInheritance").Copy();
			
			NewRow = NewRecords.Add();
			NewRow.Object   = Refs;
			NewRow.Parent = Refs;
		EndIf;
		
		Data = New Structure;
		Data.Insert("RecordSet",           RecordSet);
		Data.Insert("NewRecords",            NewRecords);
		Data.Insert("AdditionalProperties", AdditionalProperties);
		
		IsCurrentChanges = False;
		AccessManagementService.RefreshRecordset(Data, IsCurrentChanges);
		
		If IsCurrentChanges Then
			HasChanges = True;
			
			If ObjectsWithChanges <> Undefined
			   AND ObjectsWithChanges.Find(Refs) = Undefined Then
				
				ObjectsWithChanges.Add(Refs);
			EndIf;
		EndIf;
		
		If Hierarchical AND (IsCurrentChanges OR UpdateHierarchy) Then
			UpdateOwnerHierarchy(Refs, HasChanges, ObjectsWithChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure UpdateOwnerHierarchy(Refs, HasChanges, ObjectsWithChanges) Export
	
	// Update the content of items parents in the hierarchy of the current value.
	Query = New Query;
	Query.SetParameter("Ref", Refs);
	Query.Text =
	"SELECT
	|	TableWithHierarchy.Ref AS SubordinatedRef
	|FROM
	|	&TableWithHierarchy AS TableWithHierarchy
	|WHERE
	|	TableWithHierarchy.Ref IN HIERARCHY(&Ref)
	|	AND TableWithHierarchy.Ref <> &Ref";
	
	Query.Text = StrReplace(
		Query.Text, "&TableWithHierarchy", Refs.Metadata().FullName() );
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRecords = ObjectParents(Selection.SubordinatedRef, Refs);
		
		RecordSet = InformationRegisters.ObjectRightsSettingsInheritance.CreateRecordSet();
		RecordSet.Filter.Object.Set(Selection.SubordinatedRef);
		
		Data = New Structure;
		Data.Insert("RecordSet", RecordSet);
		Data.Insert("NewRecords",  NewRecords);
		
		IsCurrentChanges = False;
		AccessManagementService.RefreshRecordset(Data, IsCurrentChanges);
		
		If IsCurrentChanges Then
			HasChanges = True;
			
			If ObjectsWithChanges <> Undefined
			   AND ObjectsWithChanges.Find(Refs) = Undefined Then
				
				ObjectsWithChanges.Add(Refs);
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

// Fills in RecordSet with object parents including yourself as a parent.
//
// Parameters:
//  Refs                  - Ref in the hierarchy ObjectRef or ObjectRef.
//  ObjectRef           - Ref to a source object.
//  ObjectParentProperties - Structure with properties:
//                              Refs      - Ref to the
//                                            parent of a source object
//                                            that can differ from the parent written to the data base.
//                              Inherit - Boolean - settings inheritance by a parent.
//
// Returns:
//  RecordSet - InformationRegisterRecordSet.ObjectsRightsSettingsInheritance
//
Function ObjectParents(Refs, ObjectRef, ObjectParentProperties = "", GetInheritance = True) Export
	
	NewRecords = AccessManagementServiceReUse.EmptyRecordSetTable(
		"InformationRegister.ObjectRightsSettingsInheritance").Copy();
	
	// Receive a check box of inheritance of parents rights settings for a reference.
	If GetInheritance Then
		Inherit = SettingsInheritance(Refs);
	Else
		Inherit = True;
		NewRecords.Columns.Add("Level", New TypeDescription("Number"));
	EndIf;
	
	String = NewRecords.Add();
	String.Object      = Refs;
	String.Parent    = Refs;
	String.Inherit = Inherit;
	
	If Not Inherit Then
		Return NewRecords;
	EndIf;
	
	If Refs = ObjectRef Then
		CurrentParentProperties = ObjectParentProperties;
	Else
		CurrentParentProperties = ParentProperties(Refs);
	EndIf;
	
	While ValueIsFilled(CurrentParentProperties.Ref) Do
	
		String = NewRecords.Add();
		String.Object   = Refs;
		String.Parent = CurrentParentProperties.Ref;
		String.UseLevel = 1;
		
		If Not GetInheritance Then
			String.Level = String.Parent.Level();
		EndIf;
		
		If Not CurrentParentProperties.Inherit Then
			Break;
		EndIf;
		
		CurrentParentProperties = ParentProperties(CurrentParentProperties.Ref);
	EndDo;
	
	Return NewRecords;
	
EndFunction

Function SettingsInheritance(Refs) Export
	
	Query = New Query;
	Query.SetParameter("Ref", Refs);
	
	Query.Text =
	"SELECT
	|	SettingsInheritance.Inherit
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|WHERE
	|	SettingsInheritance.Object = &Ref
	|	AND SettingsInheritance.Parent = &Ref";
	
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.Inherit, True);
	
EndFunction

Function ParentProperties(Refs)
	
	Query = New Query;
	Query.SetParameter("Ref", Refs);
	Query.Text =
	"SELECT
	|	CurrentTable.Parent
	|INTO ParentReferences
	|FROM
	|	ObjectsTable AS CurrentTable
	|WHERE
	|	CurrentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ParentReferences.Parent
	|FROM
	|	ParentReferences AS ParentReferences
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Parents.Inherit AS Inherit
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS Parents
	|WHERE
	|	Parents.Object = Parents.Parent
	|	AND Parents.Object In
	|			(SELECT
	|				ParentReferences.Parent
	|			FROM
	|				ParentReferences AS ParentReferences)";
	
	Query.Text = StrReplace(Query.Text, "ObjectsTable", Refs.Metadata().FullName());
	
	ResultsOfQuery = Query.ExecuteBatch();
	Selection = ResultsOfQuery[1].Select();
	Parent = ?(Selection.Next(), Selection.Parent, Undefined);
	
	Selection = ResultsOfQuery[2].Select();
	Inherit = ?(Selection.Next(), Selection.Inherit, True);
	
	Return New Structure("Ref, Inherit", Parent, Inherit);
	
EndFunction

#EndRegion

#EndIf
