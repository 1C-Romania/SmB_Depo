#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Updates possible rights to set objects rights and saves the content of the last changes.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if the
//                  changes are found, True is set, otherwise, it is not changed.
//
Procedure UpdatePossibleRightsForObjectRightsSettings(HasChanges = Undefined, CheckOnly = False) Export
	
	If CheckOnly OR ExclusiveMode() Then
		SwitchOffSoleMode = False;
	Else
		SwitchOffSoleMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	PossibleRights = PossibleRights();
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.AccessLimitationParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Parameters = StandardSubsystemsServer.ApplicationWorkParameters(
			"AccessLimitationParameters");
		
		Saved = Undefined;
		
		If Parameters.Property("PossibleRightsForObjectRightsSettings") Then
			Saved = Parameters.PossibleRightsForObjectRightsSettings;
			
			If Not CommonUse.DataMatch(PossibleRights, Saved) Then
				Saved = Undefined;
			EndIf;
		EndIf;
		
		SetPrivilegedMode(True);
		
		If Saved = Undefined Then
			HasChanges = True;
			If CheckOnly Then
				CommitTransaction();
				Return;
			EndIf;
			StandardSubsystemsServer.SetApplicationPerformenceParameter(
				"AccessLimitationParameters",
				"PossibleRightsForObjectRightsSettings",
				PossibleRights);
		EndIf;
		
		StandardSubsystemsServer.ConfirmUpdatingApplicationWorkParameter(
			"AccessLimitationParameters",
			"PossibleRightsForObjectRightsSettings");
		
		If Not CheckOnly Then
			StandardSubsystemsServer.AddChangesToApplicationPerformenceParameters(
				"AccessLimitationParameters",
				"PossibleRightsForObjectRightsSettings",
				?(Saved = Undefined,
				  New FixedStructure("HasChanges", True),
				  New FixedStructure()) );
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If SwitchOffSoleMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If SwitchOffSoleMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

// Procedure updates helper register data by
// the result of possible rights change by access values saved in the parameters of access restriction.
//
Procedure UpdateRegisterAuxiliaryDataByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	Parameters = AccessManagementServiceReUse.Parameters();
	
	LastChanges = StandardSubsystemsServer.ApplicationPerformenceParameterChanging(
		Parameters, "PossibleRightsForObjectRightsSettings");
		
	If LastChanges = Undefined Then
		UpdateNeeded = True;
	Else
		UpdateNeeded = False;
		For Each ChangesPart IN LastChanges Do
			
			If TypeOf(ChangesPart) = Type("FixedStructure")
			   AND ChangesPart.Property("HasChanges")
			   AND TypeOf(ChangesPart.HasChanges) = Type("Boolean") Then
				
				If ChangesPart.HasChanges Then
					UpdateNeeded = True;
					Break;
				EndIf;
			Else
				UpdateNeeded = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If UpdateNeeded Then
		UpdateAuxiliaryRegisterData();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the object rights settings.
//
// Parameters:
//  ObjectReference - ref to the object for which you need to read rights settings.
//
// Returns:
//  Structure
//    Inherit        - Boolean - check box of inheritance of parents rights settings.
//    Settings          - ValueTable
//                         - SettingOwner     - ref to an object or
//                                                   an object parent (from the object parent hierarchy).
//                         - InheritanceAllowed - Boolean - inheritance is allowed.
//                         - User          - CatalogRef.Users
//                                                   CatalogRef.UsersGroups
//                                                   CatalogRef.ExternalUsers
//                                                   CatalogRef.ExternalUsersGroups.
//                         - <RightName1>           - Undefined,
//                                                       Boolean Undefined - right
//                                                       is not set, True       - right
//                                                       is allowed, False         - right is denied.
//                         - <RightName2>           - ...
//
Function Read(Val ObjectReference) Export
	
	PossibleRights = AccessManagementServiceReUse.Parameters(
		).PossibleRightsForObjectRightsSettings;
	
	RightsDescriptionFull = PossibleRights.ByTypes.Get(TypeOf(ObjectReference));
	
	If RightsDescriptionFull = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Error in the InformationRegisters procedure.ObjectRightsSettings.Read()
		|
		|Wrong value of the RefToObject %1 parameter.
		|Rights are not set for the %2 table objects.';ru='Ошибка в процедуре РегистрыСведений.НастройкиПравОбъектов.Прочитать() Неверное значение параметра СсылкаНаОбъект ""%1"". Для объектов таблицы ""%2"" права не настраиваются.'"),
			String(ObjectReference),
			ObjectReference.Metadata().FullName());
	EndIf;
	
	RightSettings = New Structure;
	
	// Receive value of inheritance setting.
	RightSettings.Insert("Inherit",
		InformationRegisters.ObjectRightsSettingsInheritance.SettingsInheritance(ObjectReference));
	
	// Prepare the structure of rights settings table.
	Settings = New ValueTable;
	Settings.Columns.Add("User");
	Settings.Columns.Add("SettingOwner");
	Settings.Columns.Add("InheritanceAllowed", New TypeDescription("Boolean"));
	Settings.Columns.Add("ParentSettings",     New TypeDescription("Boolean"));
	For Each RightDetails IN RightsDescriptionFull Do
		Settings.Columns.Add(RightDetails.Key);
	EndDo;
	
	If PossibleRights.HierarchicalTables.Get(TypeOf(ObjectReference)) = Undefined Then
		SettingsInheritance = AccessManagementServiceReUse.EmptyRecordSetTable(
			"InformationRegister.ObjectRightsSettingsInheritance").Copy();
		NewRow = SettingsInheritance.Add();
		SettingsInheritance.Columns.Add("Level", New TypeDescription("Number"));
		NewRow.Object   = ObjectReference;
		NewRow.Parent = ObjectReference;
	Else
		SettingsInheritance = InformationRegisters.ObjectRightsSettingsInheritance.ObjectParents(
			ObjectReference, , , False);
	EndIf;
	
	// Read settings of object and parents from which the settings are inherited.
	Query = New Query;
	Query.SetParameter("Object", ObjectReference);
	Query.SetParameter("SettingsInheritance", SettingsInheritance);
	Query.Text =
	"SELECT
	|	SettingsInheritance.Object,
	|	SettingsInheritance.Parent,
	|	SettingsInheritance.Level
	|INTO SettingsInheritance
	|FROM
	|	&SettingsInheritance AS SettingsInheritance
	|
	|INDEX BY
	|	SettingsInheritance.Object,
	|	SettingsInheritance.Parent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SettingsInheritance.Parent AS SettingOwner,
	|	ObjectRightsSettings.User AS User,
	|	ObjectRightsSettings.Right AS Right,
	|	CASE
	|		WHEN SettingsInheritance.Parent <> &Object
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ParentSettings,
	|	ObjectRightsSettings.RightDenied AS RightDenied,
	|	ObjectRightsSettings.InheritanceAllowed AS InheritanceAllowed
	|FROM
	|	InformationRegister.ObjectRightsSettings AS ObjectRightsSettings
	|		INNER JOIN SettingsInheritance AS SettingsInheritance
	|		ON ObjectRightsSettings.Object = SettingsInheritance.Parent
	|WHERE
	|	Not(SettingsInheritance.Parent <> &Object
	|				AND ObjectRightsSettings.InheritanceAllowed <> TRUE)
	|
	|ORDER BY
	|	ParentSettings DESC,
	|	SettingsInheritance.Level,
	|	ObjectRightsSettings.SetupOrder";
	Table = Query.Execute().Unload();
	
	CurrentSettingOwner = Undefined;
	CurrentUser = Undefined;
	For Each String IN Table Do
		If CurrentSettingOwner <> String.SettingOwner
		 OR CurrentUser <> String.User Then
			CurrentSettingOwner = String.SettingOwner;
			CurrentUser      = String.User;
			Setting = Settings.Add();
			Setting.User      = String.User;
			Setting.SettingOwner = String.SettingOwner;
			Setting.ParentSettings = String.ParentSettings;
		EndIf;
		If Settings.Columns.Find(String.Right) = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Error in the InformationRegisters procedure.ObjectRightsSettings.Read()
		|
		|the %2 right
		|is not set for objects of the
		|%1 table, however, it is
		|written to the ObjectsRightsSettings information register for the %3 object.
		|
		|The infobase update
		|may not have been executed or executed with an error.
		|Register data is required to be corrected.';ru='Ошибка в процедуре РегистрыСведений.НастройкиПравОбъектов.Прочитать()
		|
		|Для объектов таблицы ""%1""
		|право ""%2"" не настраивается, однако оно записано
		|в регистре сведений НастройкиПравОбъектов для
		|объекта ""%3"".
		|
		|Возможно, обновление информационной базы
		|не выполнено или выполнено с ошибкой.
		|Требуется исправить данные регистра.'"),
				ObjectReference.Metadata().FullName(),
				String.Right,
				String(ObjectReference));
		EndIf;
		Setting.InheritanceAllowed = Setting.InheritanceAllowed OR String.InheritanceAllowed;
		Setting[String.Right] = Not String.RightDenied;
	EndDo;
	
	RightSettings.Insert("Settings", Settings);
	
	Return RightSettings;
	
EndFunction

// Writes the object rights settings.
//
// Parameters:
//  Inherit - Boolean - check box of inheritance of parents rights settings.
//  Settings   - ValuesTable with a structure
//                returned by the Read() function only those rows are written that have SettingOwner = RefToObject.
//
Procedure Write(Val ObjectReference, Val Settings, Val Inherit) Export
	
	PossibleRights = AccessManagementServiceReUse.Parameters(
		).PossibleRightsForObjectRightsSettings;
	
	RightsDescriptionFull = PossibleRights.ByRefsTypes.Get(TypeOf(ObjectReference));
	
	If RightsDescriptionFull = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Error in the InformationRegisters procedure.ObjectRightsSettings.Read()
		|
		|Wrong value of the RefToObject %1 parameter.
		|Rights are not set for the %2 table objects.';ru='Ошибка в процедуре РегистрыСведений.НастройкиПравОбъектов.Прочитать() Неверное значение параметра СсылкаНаОбъект ""%1"". Для объектов таблицы ""%2"" права не настраиваются.'"),
			String(ObjectReference),
			ObjectReference.Metadata().FullName());
	EndIf;
	
	// Set value of inheritance setting.
	RecordSet = InformationRegisters.ObjectRightsSettingsInheritance.CreateRecordSet();
	RecordSet.Filter.Object.Set(ObjectReference);
	RecordSet.Filter.Parent.Set(ObjectReference);
	RecordSet.Read();
	
	If RecordSet.Count() = 0 Then
		InheritanceChanged = True;
		NewRecord = RecordSet.Add();
		NewRecord.Object      = ObjectReference;
		NewRecord.Parent    = ObjectReference;
		NewRecord.Inherit = Inherit;
	Else
		InheritanceChanged = RecordSet[0].Inherit <> Inherit;
		RecordSet[0].Inherit = Inherit;
	EndIf;
	
	// Prepare new settings
	NewRightsSettings = AccessManagementServiceReUse.EmptyRecordSetTable(
		"InformationRegister.ObjectRightsSettings").Copy();
	
	CommonRightsTable = Catalogs.MetadataObjectIDs.EmptyRef();
	
	Filter = New Structure("SettingOwner", ObjectReference);
	SetupOrder = 0;
	For Each Setting IN Settings.FindRows(Filter) Do
		For Each RightDetails IN RightsDescriptionFull Do
			If TypeOf(Setting[RightDetails.Name]) <> Type("Boolean") Then
				Continue;
			EndIf;
			SetupOrder = SetupOrder + 1;
			
			RightsSettings = NewRightsSettings.Add();
			RightsSettings.SetupOrder      = SetupOrder;
			RightsSettings.Object                = ObjectReference;
			RightsSettings.User          = Setting.User;
			RightsSettings.Right                 = RightDetails.Name;
			RightsSettings.RightDenied        = Not Setting[RightDetails.Name];
			RightsSettings.InheritanceAllowed = Setting.InheritanceAllowed;
			// Cache-attributes
			RightsSettings.RightPermissionLevel =
				?(RightsSettings.RightDenied, 0, ?(RightsSettings.InheritanceAllowed, 2, 1));
			RightsSettings.RightDeniedLevel =
				?(RightsSettings.RightDenied, ?(RightsSettings.InheritanceAllowed, 2, 1), 0);
			
			AddedIndividualTablesSettings = False;
			For Each KeyAndValue IN PossibleRights.SeparateTables Do
				SeparateTable = KeyAndValue.Key;
				TableReading    = RightDetails.ReadingInTables.Find(   SeparateTable) <> Undefined;
				TableChange = RightDetails.ChangingInTables.Find(SeparateTable) <> Undefined;
				If Not TableReading AND Not TableChange Then
					Continue;
				EndIf;
				AddedIndividualTablesSettings = True;
				TableRightsSetting = NewRightsSettings.Add();
				FillPropertyValues(TableRightsSetting, RightsSettings);
				TableRightsSetting.Table = SeparateTable;
				If TableReading Then
					TableRightsSetting.ReadingPermissionLevel = RightsSettings.RightPermissionLevel;
					TableRightsSetting.ReadingDeniedLevel = RightsSettings.RightDeniedLevel;
				EndIf;
				If TableChange Then
					TableRightsSetting.ChangePermissionLevel = RightsSettings.RightPermissionLevel;
					TableRightsSetting.ChangeDeniedLevel = RightsSettings.RightDeniedLevel;
				EndIf;
			EndDo;
			
			CommonReading    = RightDetails.ReadingInTables.Find(   CommonRightsTable) <> Undefined;
			CommonChange = RightDetails.ChangingInTables.Find(CommonRightsTable) <> Undefined;
			
			If Not CommonReading AND Not CommonChange AND AddedIndividualTablesSettings Then
				NewRightsSettings.Delete(RightsSettings);
			Else
				If CommonReading Then
					RightsSettings.ReadingPermissionLevel = RightsSettings.RightPermissionLevel;
					RightsSettings.ReadingDeniedLevel = RightsSettings.RightDeniedLevel;
				EndIf;
				If CommonChange Then
					RightsSettings.ChangePermissionLevel = RightsSettings.RightPermissionLevel;
					RightsSettings.ChangeDeniedLevel = RightsSettings.RightDeniedLevel;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	// Record settings of object rights and values of rights settings inheritance.
	BeginTransaction();
	Try
		Data = New Structure;
		Data.Insert("RecordSet",   InformationRegisters.ObjectRightsSettings);
		Data.Insert("NewRecords",    NewRightsSettings);
		Data.Insert("FilterField",     "Object");
		Data.Insert("FilterValue", ObjectReference);
		
		HasChanges = False;
		AccessManagementService.RefreshRecordset(Data, HasChanges);
		
		If HasChanges Then
			ObjectsWithChanges = New Array;
		Else
			ObjectsWithChanges = Undefined;
		EndIf;
		
		If InheritanceChanged Then
			RecordSet.Write();
			InformationRegisters.ObjectRightsSettingsInheritance.UpdateOwnerParents(
				ObjectReference, , True, ObjectsWithChanges);
		EndIf;
		
		If ObjectsWithChanges <> Undefined Then
			AddHierarchyObjects(ObjectReference, ObjectsWithChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Procedure updates helper register data during configuration changing.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if there
//                  is a record, True is set, otherwise, it is not changed.
//
Procedure UpdateAuxiliaryRegisterData(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	PossibleRights = AccessManagementServiceReUse.Parameters().PossibleRightsForObjectRightsSettings;
	
	TablesOfRights = New ValueTable;
	TablesOfRights.Columns.Add("RightsOwner", Metadata.InformationRegisters.ObjectRightsSettings.Dimensions.Object.Type);
	TablesOfRights.Columns.Add("Right",        Metadata.InformationRegisters.ObjectRightsSettings.Dimensions.Right.Type);
	TablesOfRights.Columns.Add("Table",      Metadata.InformationRegisters.ObjectRightsSettings.Dimensions.Table.Type);
	TablesOfRights.Columns.Add("Read",       New TypeDescription("Boolean"));
	TablesOfRights.Columns.Add("Update",    New TypeDescription("Boolean"));
	
	EmptyRefsRightsOwner = AccessManagementServiceReUse.MatchEmptyRefsToSpecifiedRefsTypes(
		"InformationRegister.ObjectRightsSettings.Dimension.Object");
	
	Filter = New Structure;
	For Each KeyAndValue IN PossibleRights.ByRefsTypes Do
		TypeOwnerRight = KeyAndValue.Key;
		RightsDescriptionFull     = KeyAndValue.Value;
		
		If EmptyRefsRightsOwner.Get(TypeOwnerRight) = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Error in
		|the UpdateSubordinateRegisterData procedure of the manager module of the ObjectsRightsSettings information register.
		|
		|Type of the %1 rights owner is not specified in the Object dimension.';ru='Ошибка в процедуре ОбновитьВспомогательныеДанныеРегистра
		|модуля менеджера регистра сведений НастройкиПравОбъектов.
		|
		|Тип владельцев прав ""%1"" не указан в измерении Объект.'"),
				TypeOwnerRight);
		EndIf;
		
		Filter.Insert("RightsOwner", EmptyRefsRightsOwner.Get(TypeOwnerRight));
		For Each RightDetails IN RightsDescriptionFull Do
			Filter.Insert("Right", RightDetails.Name);
			
			For Each Table IN RightDetails.ReadingInTables Do
				String = TablesOfRights.Add();
				FillPropertyValues(String, Filter);
				String.Table = Table;
				String.Read = True;
			EndDo;
			
			For Each Table IN RightDetails.ChangingInTables Do
				Filter.Insert("Table", Table);
				Rows = TablesOfRights.FindRows(Filter);
				If Rows.Count() = 0 Then
					String = TablesOfRights.Add();
					FillPropertyValues(String, Filter);
				Else
					String = Rows[0];
				EndIf;
				String.Update = True;
			EndDo;
		EndDo;
	EndDo;
	
	TemporaryTablesQueryText =
	"SELECT
	|	TablesOfRights.RightsOwner,
	|	TablesOfRights.Right,
	|	TablesOfRights.Table,
	|	TablesOfRights.Read,
	|	TablesOfRights.Update
	|INTO TablesOfRights
	|FROM
	|	&TablesOfRights AS TablesOfRights
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightSettings.Object AS Object,
	|	RightSettings.User AS User,
	|	RightSettings.Right,
	|	MAX(RightSettings.RightDenied) AS RightDenied,
	|	MAX(RightSettings.InheritanceAllowed) AS InheritanceAllowed,
	|	MAX(RightSettings.SetupOrder) AS SetupOrder
	|INTO RightSettings
	|FROM
	|	InformationRegister.ObjectRightsSettings AS RightSettings
	|
	|GROUP BY
	|	RightSettings.Object,
	|	RightSettings.User,
	|	RightSettings.Right
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightSettings.Object,
	|	RightSettings.User,
	|	RightSettings.Right,
	|	ISNULL(TablesOfRights.Table, VALUE(Catalog.MetadataObjectIDs.EmptyRef)) AS Table,
	|	RightSettings.RightDenied,
	|	RightSettings.InheritanceAllowed,
	|	RightSettings.SetupOrder,
	|	CASE
	|		WHEN RightSettings.RightDenied
	|			THEN 0
	|		WHEN RightSettings.InheritanceAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS RightPermissionLevel,
	|	CASE
	|		WHEN Not RightSettings.RightDenied
	|			THEN 0
	|		WHEN RightSettings.InheritanceAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS RightDeniedLevel,
	|	CASE
	|		WHEN Not ISNULL(TablesOfRights.Read, FALSE)
	|			THEN 0
	|		WHEN RightSettings.RightDenied
	|			THEN 0
	|		WHEN RightSettings.InheritanceAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ReadingPermissionLevel,
	|	CASE
	|		WHEN Not ISNULL(TablesOfRights.Read, FALSE)
	|			THEN 0
	|		WHEN Not RightSettings.RightDenied
	|			THEN 0
	|		WHEN RightSettings.InheritanceAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ReadingDeniedLevel,
	|	CASE
	|		WHEN Not ISNULL(TablesOfRights.Update, FALSE)
	|			THEN 0
	|		WHEN RightSettings.RightDenied
	|			THEN 0
	|		WHEN RightSettings.InheritanceAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ChangePermissionLevel,
	|	CASE
	|		WHEN Not ISNULL(TablesOfRights.Update, FALSE)
	|			THEN 0
	|		WHEN Not RightSettings.RightDenied
	|			THEN 0
	|		WHEN RightSettings.InheritanceAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ChangeDeniedLevel
	|INTO NewData
	|FROM
	|	RightSettings AS RightSettings
	|		LEFT JOIN TablesOfRights AS TablesOfRights
	|		ON (VALUETYPE(RightSettings.Object) = VALUETYPE(TablesOfRights.RightsOwner))
	|			AND RightSettings.Right = TablesOfRights.Right
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TablesOfRights
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP RightSettings";
	
	QueryText =
	"SELECT
	|	NewData.Object,
	|	NewData.User,
	|	NewData.Right,
	|	NewData.Table,
	|	NewData.RightDenied,
	|	NewData.InheritanceAllowed,
	|	NewData.SetupOrder,
	|	NewData.RightPermissionLevel,
	|	NewData.RightDeniedLevel,
	|	NewData.ReadingPermissionLevel,
	|	NewData.ReadingDeniedLevel,
	|	NewData.ChangePermissionLevel,
	|	NewData.ChangeDeniedLevel,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	NewData AS NewData";
	
	// Prepare the selected fields with an optional filter.
	Fields = New Array;
	Fields.Add(New Structure("Object"));
	Fields.Add(New Structure("User"));
	Fields.Add(New Structure("Right"));
	Fields.Add(New Structure("Table"));
	Fields.Add(New Structure("RightDenied"));
	Fields.Add(New Structure("InheritanceAllowed"));
	Fields.Add(New Structure("SetupOrder"));
	Fields.Add(New Structure("RightPermissionLevel"));
	Fields.Add(New Structure("RightDeniedLevel"));
	Fields.Add(New Structure("ReadingPermissionLevel"));
	Fields.Add(New Structure("ReadingDeniedLevel"));
	Fields.Add(New Structure("ChangePermissionLevel"));
	Fields.Add(New Structure("ChangeDeniedLevel"));
	
	Query = New Query;
	Query.SetParameter("TablesOfRights", TablesOfRights);
	
	Query.Text = AccessManagementService.TextOfQuerySelectionChanges(
		QueryText, Fields, "InformationRegister.ObjectRightsSettings", TemporaryTablesQueryText);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ObjectRightsSettings");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Data = New Structure;
		Data.Insert("ManagerRegister",      InformationRegisters.ObjectRightsSettings);
		Data.Insert("ChangeRowsContent", Query.Execute().Unload());
		
		AccessManagementService.RefreshInformationRegister(Data, HasChanges);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

Procedure AddHierarchyObjects(Refs, ObjectsArray)
	
	Query = New Query;
	Query.SetParameter("Ref", Refs);
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text = StrReplace(
	"SELECT
	|	TableWithHierarchy.Ref
	|FROM
	|	ObjectsTable AS TableWithHierarchy
	|WHERE
	|	TableWithHierarchy.Ref IN HIERARCHY(&Refs)
	|	AND Not TableWithHierarchy.Ref IN (&ObjectsArray)",
	"ObjectsTable",
	Refs.Metadata().FullName());
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ObjectsArray.Add(Selection.Ref);
	EndDo;
	
EndProcedure

// Returns a table of possible rights assigned to
// objects, specified types created using the procedure prepared by an application developer.
// OnFillingPossibleRightsForObjectRightsSettings in the common module.
// AccessManagementPredefined.
//
// Returns:
//  ValuesTable
//   RightsOwner - String - full name of
//   access value table, Name          - String - right identifier,
//                  for example, FoldersChange, right with the RightsManagement names must be defined for
//                  a
//                  common form of the rights settings Access rights, Rights management - this is a right to change rights
//                  by right owner that is checked during opening InformationRegister.ObjectsRightsSettings.Form.ObjectsRightsSettings;
//   Title    - String - title of a right, for example, in the ObjectsRightsSettings form:
//                  Change.
//                  |folders;
//   ToolTip    - String - tooltip to the right title, for example, Adding, changing and marking of folders deletion;
//   InitialValue - Boolean - an initial value of the right check box during adding of
//                                a new row in the Rights by access values form;
//   RequiredRights - Strings array - name of rights required for
//                  this right, for example, the FileAdding right requires the FileChanging right;
//   ReadingInTables - Strings array - tables full names for which this right means the Reading right;
//                  the * character may be used. It means "for
//                  all other tables" as the Reading rule can depend only on the Reading rule, then only the
//                  * character makes sense (required for working of access restriction templates);
//   ChangingInTables - Strings array - full names of the tables for which this right means the Changing right;
//                  the * character may be used. It means "for
//                  all other tables" (required for working of access restriction templates)
//
Function PossibleRights()
	
	PossibleRights = New ValueTable();
	PossibleRights.Columns.Add("RightsOwner",        New TypeDescription("String"));
	PossibleRights.Columns.Add("Name",                 New TypeDescription("String", , New StringQualifiers(60)));
	PossibleRights.Columns.Add("Title",           New TypeDescription("String", , New StringQualifiers(60)));
	PossibleRights.Columns.Add("ToolTip",           New TypeDescription("String", , New StringQualifiers(150)));
	PossibleRights.Columns.Add("InitialValue",   New TypeDescription("Boolean,Number"));
	PossibleRights.Columns.Add("RequiredRights",      New TypeDescription("Array"));
	PossibleRights.Columns.Add("ReadingInTables",     New TypeDescription("Array"));
	PossibleRights.Columns.Add("ChangingInTables",  New TypeDescription("Array"));
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AccessManagement\OnFillingInPossibleRightsForObjectRightsSettings");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnFillingInPossibleRightsForObjectRightsSettings(PossibleRights);
	EndDo;
	
	AccessManagementOverridable.OnFillingInPossibleRightsForObjectRightsSettings(PossibleRights);
	
	ErrorTitle =
		NStr("en='Error in
		|the OnFillingPossibleRightsForSettingObjectRights procedure of the AccessManagementPredefined common module.';ru='Ошибка
		|в процедуре ПриЗаполненииВозможныхПравДляНастройкиПравОбъектов общего модуля УправлениеДоступомПереопределяемый.'")
		+ Chars.LF
		+ Chars.LF;
	
	ByTypes              = New Map;
	ByRefsTypes        = New Map;
	ByFullNames       = New Map;
	OwnerTypes       = New Array;
	SeparateTables     = New Map;
	HierarchicalTables = New Map;
	
	RightsOwnersDefinedType  = AccessManagementServiceReUse.TypesTableFields("DefinedType.RightSettingsOwner");
	AccessValuesDefinedType = AccessManagementServiceReUse.TypesTableFields("DefinedType.AccessValue");
	
	AccessKindsProperties = StandardSubsystemsServer.ApplicationWorkParameters(
		"AccessLimitationParameters").AccessKindsProperties;
	
	SubscriptionTypesUpdateAccessValuesGroups = AccessManagementServiceReUse.TypesOfObjectsInSubscriptionsToEvents(
		"RefreshAccessValuesGroups");
	
	SubscriptionTypesWriteAccessValuesSets = AccessManagementServiceReUse.TypesOfObjectsInSubscriptionsToEvents(
		"RecordSetsOfAccessValues");
	
	SubscriptionTypesWriteDependentAccessValuesSets = AccessManagementServiceReUse.TypesOfObjectsInSubscriptionsToEvents(
		"RecordDependentSetsOfAccessValues");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("RightsOwner");
	AdditionalParameters.Insert("OwnersCommonRights", New Map);
	AdditionalParameters.Insert("IndividualOwnersRights", New Map);
	
	OwnersRightsIndexes = New Map;
	
	For Each PossibleRight IN PossibleRights Do
		MetadataObjectOwner = Metadata.FindByFullName(PossibleRight.RightsOwner);
		
		If MetadataObjectOwner = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorTitle + NStr("en='Owner of %1 rights is not found.';ru='Не найден владелец прав ""%1"".'"),
				PossibleRight.RightsOwner);
		EndIf;
		
		AdditionalParameters.RightsOwner = PossibleRight.RightsOwner;
		
		FillIDs("ReadingInTables",    PossibleRight, ErrorTitle, SeparateTables, AdditionalParameters);
		FillIDs("ChangingInTables", PossibleRight, ErrorTitle, SeparateTables, AdditionalParameters);
		
		OwnerRights = ByFullNames[PossibleRight.RightsOwner];
		If OwnerRights = Undefined Then
			OwnerRights = New Map;
			OwnerRightsArray = New Array;
			
			ReferenceType = StandardSubsystemsServer.TypeOfRefOrRecordKeyOfMetadataObject(
				MetadataObjectOwner);
			
			ObjectType = StandardSubsystemsServer.ObjectTypeOrSetOfMetadataObject(
				MetadataObjectOwner);
			
			If RightsOwnersDefinedType.Get(ReferenceType) = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en='Type of the
		|%1 rights owner is not specified in the Owner of rights settings defined type.';ru='Тип
		|владельца прав ""%1"" не указан в определяемом типе ""Владелец настроек прав"".'"),
					String(ReferenceType));
			EndIf;
			
			If (SubscriptionTypesWriteDependentAccessValuesSets.Get(ObjectType) <> Undefined
			      OR SubscriptionTypesWriteAccessValuesSets.Get(ObjectType) <> Undefined)
			    AND AccessValuesDefinedType.Get(ReferenceType) = Undefined Then
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en='Type of the
		|%1 rights owner is not specified in
		|the Access value defined type but used
		|for filling the sets of access values as specified in one of
		|the subscriptions
		|to the event: - WriteDependentAccessValuesSet*, - WriteAccessValuesSets*.
		|You need to specify the type in
		|the Access value specified type for the correct filling of the AccessValuesSets register.';ru='Тип владельца прав ""%1""
		|не указан в определяемом типе ""Значение доступа"",
		|но используется для заполнения наборов значений доступа,
		|т.к. указан в одной из подписок на событие:
		|- ЗаписатьЗависимыеНаборыЗначенийДоступа*,
		|- ЗаписатьНаборыЗначенийДоступа*.
		|Требуется указать тип в определяемом типе ""Значение доступа""
		|для корректного заполнения регистра НаборыЗначенийДоступа.'"),
					String(ReferenceType));
			EndIf;
			
			If AccessKindsProperties.ByValuesTypes.Get(ReferenceType) <> Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en='Type of the
		|%1 rights owner can not be used
		|as the type of access values but can be found in the description of %2 access kind.';ru='Тип
		|владельца прав ""%1"" не может
		|использоваться, как тип значений доступа, но обнаружен в описании вида доступа ""%2"".'"),
					String(ReferenceType),
					AccessKindsProperties.ByValuesTypes.Get(ReferenceType).Name);
			EndIf;
			
			If AccessKindsProperties.ByGroupsAndValuesTypes.Get(ReferenceType) <> Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en='Type of the
		|%1 rights owner can not be used as
		|the type of access values group but can be found in the description of the %2 access kind.';ru='Тип
		|владельца прав ""%1"" не может использоваться,
		|как тип групп значений доступа, но обнаружен в описании вида доступа ""%2"".'"),
					String(ReferenceType),
					AccessKindsProperties.ByValuesTypes.Get(ReferenceType).Name);
			EndIf;
			
			If SubscriptionTypesUpdateAccessValuesGroups.Get(ObjectType) = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en='Type of the
		|%1 rights owner is not specified in the subscription to the Update groups of access values event.';ru='Тип
		|владельца прав ""%1"" не указан в подписке на событие ""Обновить группы значений доступа"".'"),
					String(ObjectType));
			EndIf;
			
			ByFullNames.Insert(PossibleRight.RightsOwner, OwnerRights);
			ByRefsTypes.Insert(ReferenceType,  OwnerRightsArray);
			ByTypes.Insert(ReferenceType,  OwnerRights);
			ByTypes.Insert(ObjectType, OwnerRights);
			If HierarchicalMetadataObject(MetadataObjectOwner) Then
				HierarchicalTables.Insert(ReferenceType,  True);
				HierarchicalTables.Insert(ObjectType, True);
			EndIf;
			
			OwnerTypes.Add(CommonUse.ObjectManagerByFullName(
				PossibleRight.RightsOwner).EmptyRef());
				
			OwnersRightsIndexes.Insert(PossibleRight.RightsOwner, 0);
		EndIf;
		
		If OwnerRights.Get(PossibleRight.Name) <> Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorTitle +
				NStr("en='For the %1
		|rights owner the %2 right is defined again.';ru='Для владельца
		|прав ""%1"" повторно определено право ""%2"".'"),
				PossibleRight.RightsOwner,
				PossibleRight.Name);
		EndIf;
		
		// Convert lists of required rights to arrays.
		Delimiter = "|";
		For IndexOf = 0 To PossibleRight.RequiredRights.Count()-1 Do
			If Find(PossibleRight.RequiredRights[IndexOf], Delimiter) > 0 Then
				PossibleRight.RequiredRights[IndexOf] =
					StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
						PossibleRight.RequiredRights[IndexOf],
						Delimiter);
			EndIf;
		EndDo;
		
		PropertiesPossibleRights = New Structure(
			"RightsOwner,
			|Name,
			|Title,
			|ToolTip,
			|InitialValue,
			|RequiredRights,
			|ReadingInTables,
			|ChangingInTables,
			|RightIndex");
		FillPropertyValues(PropertiesPossibleRights, PossibleRight);
		PropertiesPossibleRights.RightIndex = OwnersRightsIndexes[PossibleRight.RightsOwner];
		OwnersRightsIndexes[PossibleRight.RightsOwner] = PropertiesPossibleRights.RightIndex + 1;
		
		OwnerRights.Insert(PossibleRight.Name, PropertiesPossibleRights);
		OwnerRightsArray.Add(PropertiesPossibleRights);
	EndDo;
	
	// Addition of separate tables.
	CommonTable = Catalogs.MetadataObjectIDs.EmptyRef();
	For Each RightsDescriptionFull IN ByFullNames Do
		SeparateRights = AdditionalParameters.IndividualOwnersRights.Get(RightsDescriptionFull.Key);
		For Each RightDetails IN RightsDescriptionFull.Value Do
			RightsProperties = RightDetails.Value;
			If RightsProperties.ChangingInTables.Find(CommonTable) <> Undefined Then
				For Each KeyAndValue IN SeparateTables Do
					SeparateTable = KeyAndValue.Key;
					
					If SeparateRights.ChangingInTables[SeparateTable] = Undefined
					   AND RightsProperties.ChangingInTables.Find(SeparateTable) = Undefined Then
					
						RightsProperties.ChangingInTables.Add(SeparateTable);
					EndIf;
				EndDo;
			EndIf;
		EndDo;
	EndDo;
	
	PossibleRights = New Structure;
	PossibleRights.Insert("ByTypes",                       ByTypes);
	PossibleRights.Insert("ByRefsTypes",                 ByRefsTypes);
	PossibleRights.Insert("ByFullNames",                ByFullNames);
	PossibleRights.Insert("OwnerTypes",                OwnerTypes);
	PossibleRights.Insert("SeparateTables",              SeparateTables);
	PossibleRights.Insert("HierarchicalTables",          HierarchicalTables);
	
	Return CommonUse.FixedData(PossibleRights);
	
EndFunction

Procedure FillIDs(Property, PossibleRight, ErrorTitle, SeparateTables, AdditionalParameters)
	
	If AdditionalParameters.OwnersCommonRights.Get(AdditionalParameters.RightsOwner) = Undefined Then
		CommonRights     = New Structure("ReadingInTables, ChangingInTables", "", "");
		SeparateRights = New Structure("ReadingInTables, ChangingInTables", New Map, New Map);
		
		AdditionalParameters.OwnersCommonRights.Insert(AdditionalParameters.RightsOwner, CommonRights);
		AdditionalParameters.IndividualOwnersRights.Insert(AdditionalParameters.RightsOwner, SeparateRights);
	Else
		CommonRights     = AdditionalParameters.OwnersCommonRights.Get(AdditionalParameters.RightsOwner);
		SeparateRights = AdditionalParameters.IndividualOwnersRights.Get(AdditionalParameters.RightsOwner);
	EndIf;
	
	Array = New Array;
	
	For Each Value IN PossibleRight[Property] Do
		
		If Value = "*" Then
			If PossibleRight[Property].Count() <> 1 Then
				
				If Property = "ReadingInTables" Then
					ErrorDescription = NStr("en='Character ""*"" is
		|specified for the %1 rights owner for %2 right in tables for reading.
		|In this case separate tables should not be specified.';ru='Для владельца
		|прав ""%1"" для права ""%2"" в таблицах для чтения указан символ ""*"".
		|В этом случае отдельных таблиц указывать не нужно.'")
				Else
					ErrorDescription = NStr("en='Character ""*"" is
		|specified for the %1 rights owner for %2 right in tables for changing.
		|In this case separate tables should not be specified.';ru='Для владельца
		|прав ""%1"" для права ""%2"" в таблицах для изменения указан символ ""*"".
		|В этом случае отдельных таблиц указывать не нужно.'")
				EndIf;
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle + ErrorDescription,
					AdditionalParameters.RightsOwner,
					PossibleRight.Name);
			EndIf;
			
			If ValueIsFilled(CommonRights[Property]) Then
				
				If Property = "ReadingInTables" Then
					ErrorDescription = NStr("en='Character ""*"" is
		|specified for the %1 rights owner for %2 right in tables for reading.
		|However, the * character is already specified in the tables for reading for %3 right.';ru='Для владельца
		|прав ""%1"" для права ""%2"" в таблицах для чтения указан символ ""*"".
		|Однако символ ""*"" уже указан в таблицах для чтения для права ""%3"".'")
				Else
					ErrorDescription = NStr("en='Character ""*"" is
		|specified for the %1 rights owner for %2 right in tables for changing.
		|However, the * character is already specified in the tables for changing for %3 right.';ru='Для владельца
		|прав ""%1"" для права ""%2"" в таблицах для изменения указан символ ""*"".
		|Однако символ ""*"" уже указан в таблицах для изменения для права ""%3"".'")
				EndIf;
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle + ErrorDescription,
					AdditionalParameters.RightsOwner,
					PossibleRight.Name,
					CommonRights[Property]);
			Else
				CommonRights[Property] = PossibleRight.Name;
			EndIf;
			
			Array.Add(Catalogs.MetadataObjectIDs.EmptyRef());
			
		ElsIf Property = "ReadingInTables" Then
			ErrorDescription =
				NStr("en='For the %1
		|rights owner for %2 right the specified table for reading %3 is specified.
		|However, it makes no sense as the Reading right can only depend on the Reading right
		|It makes sense to use only the * character.';ru='Для владельца прав ""%1""
		|для права ""%2"" указана конкретная таблица для чтения ""%3"".
		|Однако это не имеет смысла, т.к. право Чтение может зависеть только от права Чтение.
		|Имеет смысл использовать только символ ""*"".'");
				
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorTitle + ErrorDescription,
				AdditionalParameters.RightsOwner,
				PossibleRight.Name,
				Value);
			
		ElsIf Metadata.FindByFullName(Value) = Undefined Then
			
			If Property = "ReadingInTables" Then
				ErrorDescription = NStr("en='For the %1
		|rights owner for %2 right the table for reading %3 is not found.';ru='Для владельца
		|прав ""%1"" для права ""%2"" не найдена таблица для чтения ""%3"".'")
			Else
				ErrorDescription = NStr("en='For the %1
		|rights owner for %2 right the table for changing %3 is not found.';ru='Для владельца
		|прав ""%1"" для права ""%2"" не найдена таблица для изменения ""%3"".'")
			EndIf;
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorTitle + ErrorDescription,
				AdditionalParameters.RightsOwner,
				PossibleRight.Name,
				Value);
		Else
			TableID = CommonUse.MetadataObjectID(Value);
			Array.Add(TableID);
			
			SeparateTables.Insert(TableID, Value);
			SeparateRights[Property].Insert(TableID, PossibleRight.Name);
		EndIf;
		
	EndDo;
	
	PossibleRight[Property] = Array;
	
EndProcedure

Function HierarchicalMetadataObject(MetadataObjectDesc)
	
	If TypeOf(MetadataObjectDesc) = Type("String") Then
		MetadataObject = Metadata.FindByFullName(MetadataObjectDesc);
	ElsIf TypeOf(MetadataObjectDesc) = Type("Type") Then
		MetadataObject = Metadata.FindByType(MetadataObjectDesc);
	Else
		MetadataObject = MetadataObjectDesc;
	EndIf;
	
	If TypeOf(MetadataObject) <> Type("MetadataObject") Then
		Return False;
	EndIf;
	
	If Not Metadata.Catalogs.Contains(MetadataObject)
	   AND Not Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) Then
		
		Return False;
	EndIf;
	
	Return MetadataObject.Hierarchical;
	
EndFunction

#EndRegion

#EndIf
