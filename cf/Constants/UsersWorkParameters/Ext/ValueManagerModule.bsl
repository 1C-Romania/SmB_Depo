#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Procedure updates common parameters of users on change of the configuration.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if there
//                  is a record, True is set, otherwise, it is not changed.
//
Procedure RefreshGeneralParameters(HasChanges = Undefined, CheckOnly = False) Export
	
	SetPrivilegedMode(True);
	
	If CheckOnly OR ExclusiveMode() Then
		SwitchOffSoleMode = False;
	Else
		SwitchOffSoleMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	UnavailableRolesByUserTypes = UnavailableRolesByUserTypes();
	
	AllRoles = AllRoles();
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.UsersWorkParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Parameters = StandardSubsystemsServer.ApplicationWorkParameters(
			"UsersWorkParameters");
		
		// Check and update of UnavailableRolesByUserTypes parameter.
		Saved = Undefined;
		
		If Parameters.Property("UnavailableRolesByUserTypes") Then
			Saved = Parameters.UnavailableRolesByUserTypes;
			
			If Not CommonUse.DataMatch(
			          UnavailableRolesByUserTypes, Saved) Then
				
				Saved = Undefined;
			EndIf;
		EndIf;
		
		If Saved = Undefined Then
			HasChanges = True;
			If CheckOnly Then
				CommitTransaction();
				Return;
			EndIf;
			StandardSubsystemsServer.SetApplicationPerformenceParameter(
				"UsersWorkParameters",
				"UnavailableRolesByUserTypes",
				UnavailableRolesByUserTypes);
		EndIf;
		
		StandardSubsystemsServer.ConfirmUpdatingApplicationWorkParameter(
			"UsersWorkParameters", "UnavailableRolesByUserTypes");
		
		// Check and update of AllRoles parameter.
		Saved = Undefined;
		
		If Parameters.Property("AllRoles") Then
			Saved = Parameters.AllRoles;
			
			If Not CommonUse.DataMatch(AllRoles, Saved) Then
				Saved = Undefined;
			EndIf;
		EndIf;
		
		If Saved = Undefined Then
			HasChanges = True;
			If CheckOnly Then
				CommitTransaction();
				Return;
			EndIf;
			StandardSubsystemsServer.SetApplicationPerformenceParameter(
				"UsersWorkParameters",
				"AllRoles",
				AllRoles);
		EndIf;
		
		StandardSubsystemsServer.ConfirmUpdatingApplicationWorkParameter(
			"UsersWorkParameters", "AllRoles");
		
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

#EndRegion

#Region ServiceProceduresAndFunctions

Function UnavailableRolesByUserTypes()
	
	InaccessibleRights                         = InaccessibleRightsByTypesUsers();
	CommonDataChangeAllowed            = CommonDataChangeAllowed();
	UnseparatedDataAvailableForChange = UnseparatedDataAvailableForChange();
	
	
	UnavailableRolesByUserTypes = New Map;
	
	For Each UsersType IN Enums.UserTypes Do
		InaccessibleRoles = New Map;
		
		For Each Role IN Metadata.Roles Do
			RoleName = Role.Name;
			Total = New Structure;
			FoundInaccessibleRights = New Array;
			If InaccessibleRights[UsersType] <> Undefined Then
				For Each KeyAndValue IN InaccessibleRights[UsersType] Do
					If AccessRight(KeyAndValue.Key, Metadata, Role) Then
						FoundInaccessibleRights.Add(KeyAndValue.Value);
					EndIf;
				EndDo;
				If FoundInaccessibleRights.Count() > 0 Then
					Total.Insert("Rights", FoundInaccessibleRights);
				EndIf;
			EndIf;
			
			If CommonDataChangeAllowed[UsersType] <> True Then
				Filter = New Structure("Role", RoleName);
				FoundStrings = UnseparatedDataAvailableForChange.FindRows(Filter);
				If FoundStrings.Count() > 0 Then
					
					NonseparatedVariableData =
						UnseparatedDataAvailableForChange.Copy(
							FoundStrings, "Object, Right");
					
					NonseparatedVariableData.GroupBy("Object, Right");
					Total.Insert("NonseparatedVariableData", NonseparatedVariableData);
				EndIf;
			EndIf;
			
			If Total.Count() > 0 Then
				InaccessibleRoles.Insert(RoleName, Total);
			EndIf;
		EndDo;
		
		UnavailableRolesByUserTypes.Insert(UsersType, InaccessibleRoles);
	EndDo;
	
	Return CommonUse.FixedData(UnavailableRolesByUserTypes, False);
	
EndFunction

// Returns the table of full names of
// undivided metadata objects and corresponding sets of access rights.
//
// Returns:
//  ValuesTable with columns: 
//   * Role   - String - Role name.
//   * Object - String - Full name of metadata object.
//   * Right  - String - Access right name.
//
Function UnseparatedDataAvailableForChange() Export
	
	CommonTable = New ValueTable;
	CommonTable.Columns.Add("Role",   New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	CommonTable.Columns.Add("Object", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	CommonTable.Columns.Add("Right",  New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.SaaS.BasicFunctionalitySaaS") Then
		Return CommonTable;
	EndIf;
	
	MetadataKinds = New Array;
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.ExchangePlans, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Constants, False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Catalogs, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Sequences, False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Documents, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.ChartsOfCharacteristicTypes, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.ChartsOfAccounts, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.ChartsOfCalculationTypes, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.BusinessProcesses, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Tasks, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.InformationRegisters, False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.AccumulationRegisters, False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.AccountingRegisters, False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.CalculationRegisters, False));
	
	CheckedRights = New Array;
	CheckedRights.Add(New Structure("Name, Reference", "Update",  False));
	CheckedRights.Add(New Structure("Name, Reference", "Insert", True));
	CheckedRights.Add(New Structure("Name, Reference", "Delete",   True));
	
	SetPrivilegedMode(True);
	
	ModuleSaaSReUse = CommonUse.CommonModule("SaaSReUse");
	DataModel = ModuleSaaSReUse.GetDataAreaModel();
	
	SeparatedMetadataObjects = New Map();
	For Each DataModelItem IN DataModel Do
		
		SeparatedMetadataObjects.Insert(
			Metadata.FindByFullName(DataModelItem.Key), True);
		
	EndDo;
	
	For Each KindDescription IN MetadataKinds Do // By metadata kinds.
		For Each MetadataObject IN KindDescription.Kind Do // By objects of the kind.
			
			If SeparatedMetadataObjects.Get(MetadataObject) <> Undefined Then
				Continue;
			EndIf;
			
			For Each Role IN Metadata.Roles Do
				
				If Not AccessRight("Read", MetadataObject, Role) Then
					Continue;
				EndIf;
				
				For Each RightDetails IN CheckedRights Do
					If Not RightDetails.Reference
						OR KindDescription.Reference Then
						
						If AccessRight(RightDetails.Name, MetadataObject, Role) Then
							// Common table of objects by roles.
							RowRights = CommonTable.Add();
							RowRights.Role   = Role.Name;
							RowRights.Object = MetadataObject.FullName();
							RowRights.Right  = RightDetails.Name;
						EndIf;
						
					EndIf;
				EndDo;
				
			EndDo;
		EndDo;
	EndDo;
	
	CommonTable.Indexes.Add("Role");
	Return CommonTable;
	
EndFunction

Function InaccessibleRightsByTypesUsers()
	
	InaccessibleRights = New Map;
	
	Rights = New Map;
	InaccessibleRights.Insert(Enums.UserTypes.ExternalUser, Rights);
	Rights.Insert("Administration",       NStr("en='Administration';ru='Администрирование'"));
	Rights.Insert("DataAdministration", NStr("en='Data administration';ru='Администрирование данных'"));
	
	Rights = New Map;
	InaccessibleRights.Insert(Enums.UserTypes.LocalApplicationUser, Rights);
	Rights.Insert("Administration",                     NStr("en='Administration';ru='Администрирование'"));
	Rights.Insert("UpdateDataBaseConfiguration",      NStr("en='Update infobase configuration';ru='Обновление конфигурации базы данных'"));
	
	Rights = New Map;
	InaccessibleRights.Insert(Enums.UserTypes.DataAreaUser, Rights);
	Rights.Insert("Administration",                     NStr("en='Administration';ru='Администрирование'"));
	Rights.Insert("UpdateDataBaseConfiguration",      NStr("en='Update infobase configuration';ru='Обновление конфигурации базы данных'"));
	Rights.Insert("ThickClient",                         NStr("en='Thick client';ru='Толстый клиент'"));
	Rights.Insert("ExternalConnection",                     NStr("en='External connection';ru='Внешнее соединение'"));
	Rights.Insert("Automation",                            NStr("en='Automation';ru='Automation'"));
	Rights.Insert("InteractiveOpenExtDataProcessors", NStr("en='Interactive opening of external data processors';ru='Интерактивное открытие внешних обработок'"));
	Rights.Insert("InteractiveOpenExtReports",   NStr("en='Interactive opening of external reports';ru='Интерактивное открытие внешних отчетов'"));
	Rights.Insert("AllFunctionsMode",                       NStr("en='All functions mode';ru='Режим все функции'"));
	
	Return InaccessibleRights;
	
EndFunction

Function CommonDataChangeAllowed()
	
	Total = New Map;
	
	Total.Insert(Enums.UserTypes.ExternalUser,           True);
	Total.Insert(Enums.UserTypes.LocalApplicationUser, True);
	Total.Insert(Enums.UserTypes.DataAreaUser,     False);
	
	Return Total;
	
EndFunction

Function AllRoles()
	
	Array = New Array;
	Map = New Map;
	
	Table = New ValueTable;
	Table.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(256)));
	
	For Each Role IN Metadata.Roles Do
		RoleName = Role.Name;
		
		Array.Add(RoleName);
		Map.Insert(RoleName, True);
		Table.Add().Name = RoleName;
	EndDo;
	
	AllRoles = New Structure;
	AllRoles.Insert("Array",       New FixedArray(Array));
	AllRoles.Insert("Map", New FixedMap(Map));
	AllRoles.Insert("Table",      Table);
	
	Return CommonUse.FixedData(AllRoles, False);
	
EndFunction

#EndRegion

#EndIf
