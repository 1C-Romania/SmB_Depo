#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Returns the role intended for designation
// to the user of infobase, whose username and password will
// be used for connection to standard OData interface (in service model).
//
// Return value: MetadataObject (role).
//
Function RoleForStandardODataInterface() Export
	
	Return Metadata.Roles.RemoteAccessStandardInterfaceOData;
	
EndFunction

// Returns authorization settings for standard OData interface (in service model).
//
// Return value: FixedStructure, fields:
//                        * Used - Boolean - flag of authorization for
//                                         access to standard OData
//                        interface, * Login - String - user login for authorization
//                                         in standard OData interface.
//
Function AuthorizationSettingsForStandardODataInterface() Export
	
	Result = New Structure("Used,Login");
	Result.Used = False;
	
	PropertiesUser = StandardODataInterfaceUserProperties();
	
	If ValueIsFilled(PropertiesUser.User) Then
		
		Result.Login = PropertiesUser.Name;
		Result.Used = PropertiesUser.Authentication;
		
	EndIf;
	
	Return New FixedStructure(Result);
	
EndFunction

// Writes authorization settings for standard OData interface (in service model).
//
// Parameters:
//  AuthorizationSettings - Structure, fields:
//                        * Used - Boolean - flag of authorization for
//                                         access to standard OData
//                        interface, * Login - String - user login for authorization in standard OData interface, * Password - String - user password for authorization
//                                         in standard OData interface. Value
//                                         is sent in structure content only in case when
//                                         it is required to change the password.
//
Procedure WriteAuthorizationSettingsForStandardODataInterface(Val AuthorizationSettings) Export
	
	PropertiesUser = StandardODataInterfaceUserProperties();
	
	If AuthorizationSettings.Used Then
		
		// It is required to create or update IB user
		
		CheckPossibilityToCreateUserForStandardODataInterfaceCalls();
		
		IBUserDescription = New Structure();
		IBUserDescription.Insert("Action", "Write");
		IBUserDescription.Insert("Name", AuthorizationSettings.Login);
		IBUserDescription.Insert("StandardAuthentication", True);
		IBUserDescription.Insert("OSAuthentication", False);
		IBUserDescription.Insert("OpenIDAuthentication", False);
		IBUserDescription.Insert("ShowInList", False);
		If AuthorizationSettings.Property("Password") Then
			IBUserDescription.Insert("Password", AuthorizationSettings.Password);
		EndIf;
		IBUserDescription.Insert("CannotChangePassword", True);
		IBUserDescription.Insert("Roles",
			CommonUseClientServer.ValueInArray(
			RoleForStandardODataInterface().Name));
		
		If ValueIsFilled(PropertiesUser.User) Then
			StandardInterfaceUserOData = PropertiesUser.User.GetObject();
		Else
			StandardInterfaceUserOData = Catalogs.Users.CreateItem();
		EndIf;
		
		StandardInterfaceUserOData.Description = NStr("en='Automatic REST-service';ru='Автоматический REST-сервис'");
		StandardInterfaceUserOData.Service = True;
		StandardInterfaceUserOData.AdditionalProperties.Insert("IBUserDescription", IBUserDescription);
		
		BeginTransaction();
		
		Try
			
			StandardInterfaceUserOData.Write();
			
			Constants.StandardInterfaceUserOData.Set(
				StandardInterfaceUserOData.Ref);
			
			IBUserDescription.Delete("Password");
			
			Comment = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Record of the user for standard OData interface is done. Description of IB user: ------------------------------------------- %1 ------------------------------------------- Result: ------------------------------------------- %2 -------------------------------------------';ru='Выполнена запись пользователя для стандартного интерфейса OData. Описание пользователя ИБ: ------------------------------------------- %1 ------------------------------------------- Результат: ------------------------------------------- %2 -------------------------------------------'"),
				CommonUse.ValueToXMLString(IBUserDescription),
				StandardInterfaceUserOData.AdditionalProperties.IBUserDescription.ActionResult
			);
			
			WriteLogEvent(
				EventLogMonitorEventName(NStr("en='UserRecord';ru='ЗаписьПользователя'")),
				EventLogLevel.Information,
				Metadata.Catalogs.Users,
				,
				Comment
			);
			
			CommitTransaction();
			
		Except
			
			IBUserDescription.Delete("Password");
			
			Comment = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Error occurred at recording of the user of standard OData interface. Description of IB user: ------------------------------------------- %1 ------------------------------------------- Error text: ------------------------------------------- %2 -------------------------------------------';ru='При записи пользователя для стандартного интерфейса OData произошла ошибка. Описание пользователя ИБ: ------------------------------------------- %1 ------------------------------------------- Текст ошибки: ------------------------------------------- %2 -------------------------------------------'"),
				CommonUse.ValueToXMLString(IBUserDescription),
				DetailErrorDescription(ErrorInfo())
			);
			
			WriteLogEvent(
				EventLogMonitorEventName(NStr("en='UserRecord';ru='ЗаписьПользователя'")),
				EventLogLevel.Error,
				Metadata.Catalogs.Users,
				,
				Comment
			);
			
			RollbackTransaction();
			Raise;
			
		EndTry;
		
	Else
		
		If ValueIsFilled(PropertiesUser.User) Then
			
			// It is required to block IB user
			
			IBUserDescription = New Structure();
			IBUserDescription.Insert("Action", "Write");
			
			IBUserDescription.Insert("CanLogOnToApplication", False);
			
			StandardInterfaceUserOData = PropertiesUser.User.GetObject();
			StandardInterfaceUserOData.AdditionalProperties.Insert("IBUserDescription", IBUserDescription);
			StandardInterfaceUserOData.Service = True;
			StandardInterfaceUserOData.Write();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Returns data model for objects which can be included in
// the content of standard OData interface (in service model).
//
// Return value: ValueTable, columns:
//                         * MetadataObject - MetadataObject - metadata object included
//                                              in the content of standard OData
//                         interface, * Reading - Boolean -  through standard OData interface you
//                                              can get a read
//                         access to the object, * Record - Boolean -  through standard OData interface you
//                                              can get an access
//                         to object record, * Dependencies -      Array(MetadataObject) - array of metadata
//                                              objects required to include in the content of
//                                              standard OData interface when current object is enabled.
//
Function DataModelProvidedForStandardODataInterface() Export
	
	Excluded = New Map();
	
	For Each ExcludedObject IN ObjectsExcludedFromStandardODataInterface() Do
		Excluded.Insert(ExcludedObject.FullName(), True);
	EndDo;
	
	Result = New ValueTable();
	
	Result.Columns.Add("DescriptionFull", New TypeDescription("String"));
	Result.Columns.Add("Read", New TypeDescription("Boolean"));
	Result.Columns.Add("Update", New TypeDescription("Boolean"));
	Result.Columns.Add("Dependencies", New TypeDescription("Array"));
	
	Model = CommonUseSTLReUse.ConfigurationDataModelDescription();
	
	For Each Items IN Model Do
		
		For Each KeyAndValue IN Items.Value Do
			
			ObjectDescription = KeyAndValue.Value;
			
			If Excluded.Get(ObjectDescription.DescriptionFull) <> Undefined Then
				Continue;
			EndIf;
			
			If ObjectDescription.DataSeparation.Property(SaaSOperations.MainDataSeparator()) Then
				
				FillDataModelProvidedForStandardODataInterface(Result, ObjectDescription.DescriptionFull, Excluded);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns reference role content for designation to
// the user of information database, whose username and password will be
// used for connection to standard OData interface (in service model).
//
// Return value: Compliance:
//                        * Key - MetadataObject - metadata
//                        object, * Value - Array(Row) - array of access
//                                     rights names that should be allowed for
//                                     this metadata object in the role.
//
Function ReferenceRoleContentForStandardODataInterface() Export
	
	Result = New Map();
	
	RightsKind = RightsKindsForStandardODataInterface(Metadata, False, False);
	If RightsKind.Count() > 0 Then
		Result.Insert(Metadata, RightsKind);
	EndIf;
	
	For Each SessionParameter IN Metadata.SessionParameters Do
		RightsKind = RightsKindsForStandardODataInterface(SessionParameter, True, False);
		If RightsKind.Count() > 0 Then
			Result.Insert(SessionParameter, RightsKind);
		EndIf;
	EndDo;
	
	Model = DataModelProvidedForStandardODataInterface();
	
	For Each ModelItem IN Model Do
		
		RightsKind = RightsKindsForStandardODataInterface(
			ModelItem.DescriptionFull,
			ModelItem.Read,
			ModelItem.Update);
		
		If RightsKind.Count() > 0 Then
			Result.Insert(ModelItem.DescriptionFull, RightsKind);
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Checks role content intended for designation to the
// user of infobase, whose username and password will be used
// for connection to standard OData interface (in service model).
//
// IN case of errors in role content setup - exception is being generated.
//
Procedure CheckODataRoleContent() Export
	
	Role = RoleForStandardODataInterface();
	
	ExcessiveRights = New Map();
	MissingRights = New Map();
	
	ReferenceContent = ReferenceRoleContentForStandardODataInterface();
	
	CheckODataRoleContentByMetadataObject(Metadata, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.SessionParameters, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.Constants, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.Catalogs, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.Documents, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.DocumentJournals, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.ChartsOfCharacteristicTypes, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.ChartsOfAccounts, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.ChartsOfCalculationTypes, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.ExchangePlans, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.BusinessProcesses, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.Tasks, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.Sequences, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.InformationRegisters, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.AccumulationRegisters, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.AccountingRegisters, ReferenceContent, ExcessiveRights, MissingRights);
	CheckODataRoleContentByMetadataCollection(Metadata.CalculationRegisters, ReferenceContent, ExcessiveRights, MissingRights);
	For Each CalculationRegister IN Metadata.CalculationRegisters Do
		CheckODataRoleContentByMetadataCollection(CalculationRegister.Recalculations, ReferenceContent, ExcessiveRights, MissingRights);
	EndDo;
	
	Errors = New Array();
	
	If ExcessiveRights.Count() > 0 Then
		ErrorText = Chars.NBSp + NStr("en='The following rights are excessively included in role content:';ru='Следующие права избыточно включены в состав роли:'") + Chars.LF + Chars.CR + 
			ExcessiveOrMissingRightsDisplay(ExcessiveRights, 2);
		Errors.Add(ErrorText);
	EndIf;
	
	If MissingRights.Count() > 0 Then
		ErrorText = Chars.NBSp + NStr("en='The following rights shall be included in role content:';ru='Следующие права должны быть включены в состав роли:'") + Chars.LF + Chars.CR + 
			ExcessiveOrMissingRightsDisplay(MissingRights, 2);
		Errors.Add(ErrorText);
	EndIf;
	
	If Errors.Count() > 0 Then
		
		ErrorMessage = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Errors in the content of role rights were detected %1:';ru='Обнаружены ошибки в составе прав роли %1:'"),
			RoleForStandardODataInterface().Name);
		
		For Each Error IN Errors Do
			
			ErrorMessage = ErrorMessage + Chars.LF + Chars.CR + Chars.Tab + Error;
			
		EndDo;
		
		Raise ErrorMessage;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function StandardODataInterfaceContentSettings() Export
	
	Object = Create();
	Return Object.InitializeDataToSetupStandardODataInterface();
	
EndFunction

Procedure CheckODataRoleContentByMetadataCollection(MetadataCollection, ReferenceContent, ExcessiveRights, MissingRights)
	
	For Each MetadataObject IN MetadataCollection Do
		CheckODataRoleContentByMetadataObject(MetadataObject, ReferenceContent, ExcessiveRights, MissingRights);
	EndDo;
	
EndProcedure

Procedure CheckODataRoleContentByMetadataObject(MetadataObject, ReferenceContent, ExcessiveRights, MissingRights)
	
	RightsKind = CommonUseSTL.ValidRightsForMetadataObject(MetadataObject);
	
	ReferenceRights = ReferenceContent.Get(MetadataObject.FullName());
	If ReferenceRights = Undefined Then
		ReferenceRights = New Array();
	EndIf;
	
	GrantedRights = New Array();
	For Each RightKind IN RightsKind Do
		If AccessRight(RightKind.Name, MetadataObject, RoleForStandardODataInterface()) Then
			GrantedRights.Add(RightKind.Name);
		EndIf;
	EndDo;
	
	// All rights included in the reference rights but absent in granted rights - missing
	MissingRightsForObject = New Array();
	For Each RightKind IN ReferenceRights Do
		If GrantedRights.Find(RightKind) = Undefined Then
			MissingRightsForObject.Add(RightKind);
		EndIf;
	EndDo;
	If MissingRightsForObject.Count() > 0 Then
		MissingRights.Insert(MetadataObject, MissingRightsForObject);
	EndIf;
	
	// All rights included in granted rights but absent in reference rights - excessive
	ExcessiveRightsForObject = New Array();
	For Each RightKind IN GrantedRights Do
		If ReferenceRights.Find(RightKind) = Undefined Then
			ExcessiveRightsForObject.Add(RightKind);
		EndIf;
	EndDo;
	If ExcessiveRightsForObject.Count() > 0 Then
		ExcessiveRights.Insert(MetadataObject, ExcessiveRightsForObject);
	EndIf;
	
EndProcedure

Function RightsKindsForStandardODataInterface(Val MetadataObject, Val AllowDataReading, Val AllowDataChange)
	
	AllRightsKinds = CommonUseSTL.ValidRightsForMetadataObject(MetadataObject);
	
	RightsFilter = New Structure();
	RightsFilter.Insert("Interactive", False);
	RightsFilter.Insert("InfobaseAdministration", False);
	RightsFilter.Insert("DataAreaAdministration", False);
	
	If AllowDataReading AND Not AllowDataChange Then
		RightsFilter.Insert("Read", AllowDataReading);
	EndIf;
	
	If AllowDataChange AND Not AllowDataReading Then
		RightsFilter.Insert("Update", AllowDataChange);
	EndIf;
	
	RequiredRightsKinds = AllRightsKinds.Copy(RightsFilter);
	
	Return RequiredRightsKinds.UnloadColumn("Name");
	
EndFunction

Procedure FillDataModelProvidedForStandardODataInterface(Val Result, Val DescriptionFull, Val Excluded)
	
	If Not ThisIsValidMetadataObjectOData(DescriptionFull) Then
		Return;
	EndIf;
	
	String = Result.Find(DescriptionFull, "DescriptionFull");
	If String = Undefined Then
		String = Result.Add();
	EndIf;
	
	String.DescriptionFull = DescriptionFull;
	String.Read = True;
	If CommonUseSTL.IsEnum(DescriptionFull) Then
		String.Update = False;
	ElsIf CommonUseSTL.IsDocumentJournal(DescriptionFull) Then
		String.Update = False;
	ElsIf Not CommonUseSTL.IsSeparatedMetadataObject(DescriptionFull, SaaSOperations.MainDataSeparator()) Then
		String.Update = False;
	Else
		String.Update = True;
	EndIf;
	
	Dependencies = CommonUseSTL.MetadataObjectDependence(DescriptionFull);
	
	For Each KeyAndValue IN Dependencies Do
		
		DependencyFullName = KeyAndValue.Key;
		
		If DependencyFullName = DescriptionFull Then
			Continue;
		EndIf;
		
		If Excluded.Get(DependencyFullName) <> Undefined Then
			Continue;
		EndIf;
		
		String.Dependencies.Add(DependencyFullName);
		
		DependencyString = Result.Find(DependencyFullName, "DescriptionFull");
		If DependencyString = Undefined Then
			FillDataModelProvidedForStandardODataInterface(Result, DependencyFullName, Excluded);
		EndIf;
		
	EndDo;
	
EndProcedure

Function ThisIsValidMetadataObjectOData(Val MetadataObject)
	
	If CommonUseSTL.ThisIsCatalog(MetadataObject)
		Or CommonUseSTL.ThisIsDocument(MetadataObject)
		Or CommonUseSTL.ThisIsExchangePlan(MetadataObject)
		Or CommonUseSTL.ThisIsChartOfAccounts(MetadataObject)
		Or CommonUseSTL.ThisIsChartOfCalculationTypes(MetadataObject)
		Or CommonUseSTL.ThisIsChartOfCharacteristicTypes(MetadataObject)
		Or CommonUseSTL.IsAccountingRegister(MetadataObject)
		Or CommonUseSTL.ThisIsInformationRegister(MetadataObject)
		Or CommonUseSTL.ThisIsCalculationRegister(MetadataObject)
		Or CommonUseSTL.ThisIsAccumulationRegister(MetadataObject)
		Or CommonUseSTL.IsDocumentJournal(MetadataObject)
		Or CommonUseSTL.IsEnum(MetadataObject)
		Or CommonUseSTL.ThisIsTask(MetadataObject)
		Or CommonUseSTL.ThisIsBusinessProcess(MetadataObject)
		Or CommonUseSTL.ThisIsConstant(MetadataObject) Then
		
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

Function ExcessiveOrMissingRightsDisplay(Val RightsDescriptions, Val Indent)
	
	Result = "";
	
	For Each KeyAndValue IN RightsDescriptions Do
		
		MetadataObject = KeyAndValue.Key;
		Rights = KeyAndValue.Value;
		
		String = "";
		
		For Step = 1 To Indent Do
			String = String + Chars.NBSp;
		EndDo;
		
		String = String + MetadataObject.FullName() + ": " + StringFunctionsClientServer.RowFromArraySubrows(Rights, ", ");
		
		If Not IsBlankString(Result) Then
			Result = Result + Chars.LF;
		EndIf;
		
		Result = Result + String;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function ObjectsExcludedFromStandardODataInterface()
	
	Return DataExportImportServiceEvents.GetTypesExcludedFromExportImport();
	
EndFunction

Function StandardODataInterfaceUserProperties()
	
	If Not AccessRight("DataAdministration", Metadata) Then
		Raise NStr("en='Insufficient rights to setup automatic REST-service';ru='Недостаточно прав для настройки автоматического REST-сервиса'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Result = New Structure("User, Identifier, Name, Authentication", Catalogs.Users.EmptyRef(), Undefined, "", False);
	
	User = Constants.StandardInterfaceUserOData.Get();
	
	If ValueIsFilled(User) Then
		
		Result.User = User;
		
		ID = CommonUse.ObjectAttributeValue(User, "InfobaseUserID");
		
		If ValueIsFilled(ID) Then
			
			Result.ID = ID;
			
			IBUser = InfobaseUsers.FindByUUID(ID);
			
			If IBUser <> Undefined Then
				
				Result.Name = IBUser.Name;
				Result.Authentication = IBUser.StandardAuthentication;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function EventLogMonitorEventName(Val Suffix)
	
	Return NStr("en='StandardODataInterfaceSetup.';ru='НастройкаСтандартногоИнтерфейсаOData.'") + TrimAll(Suffix);
	
EndFunction

// Adds to the Handlers
// list update handler procedures required to this subsystem.
//
// Parameters:
//   Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.InitialFilling = True;
		Handler.Procedure = "DataProcessors.StandardODataInterfaceSetup.CheckODataRoleContentWhenUpdating";
		Handler.SharedData = True;
		
	EndIf;
	
EndProcedure

Procedure CheckODataRoleContentWhenUpdating() Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		CheckODataRoleContent();
	Else
		Raise NStr("en='Handler shall not be used when division by data areas is enabled';ru='Обработчик не должен использоваться при выключенном разделении по областям данных'");
	EndIf;
	
EndProcedure

Procedure CheckPossibilityToCreateUserForStandardODataInterfaceCalls()
	
	SetPrivilegedMode(True);
	UserCount = InfobaseUsers.GetUsers().Count();
	SetPrivilegedMode(False);
	
	If UserCount = 0 Then
		
		Raise NStr("en='You can not create a separate login and password for automatic REST-service as other users are absent in the application.';ru='Нельзя создать отдельные логин и пароль для использования автоматического REST-сервиса, т.к. в программе отсутствуют другие пользователи.'");
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf