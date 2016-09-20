////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of common use:
// - Support works with included security profiles.
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

////////////////////////////////////////////////////////////////////////////////
// Functions-constructors of permissions.
//

// Returns the internal description of the permission to use the directory of file system.
//
// Parameters:
//  Address - String - address of file
//  system resource, DataReading - Boolean - flag which indicates the
//    necessity to provide the permission to read data
//  from this directory of file system, DataRecording - Boolean - flag which indicates the
//    necessity to provide the permission to record data
//  in the specified directory of file system, Description - String - Description of a reason for which it is required to grant a permission.
//
// Returns:
//  XDTODataObject - internal description of requested permission.
//  Intended only for transfer as a parameter in the function.
//  WorkInSafeMode.QueryOnExternalResourcesUse(),
//  WorkInSafeMode.QueryOnCancelingPermissionsToUseExternalResources()
//  and WorkInSafeMode.QueryOnClearingPermissionToUseExternalResources().
//
Function PermissionToUseFileSystemDirectory(Val Address, Val DataReading = False, Val DataRecording = False, Val Description = "") Export
	
	Package = WorkInSafeModeService.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "FileSystemAccess"));
	Result.Description = Description;
	
	If Right(Address, 1) = "\" Or Right(Address, 1) = "/" Then
		Address = Left(Address, StrLen(Address) - 1);
	EndIf;
	
	Result.Path = Address;
	Result.AllowedRead = DataReading;
	Result.AllowedWrite = DataRecording;
	
	Return Result;
	
EndFunction

// Returns the internal description of the permission to use the directory of temporary files.
//
// Parameters:
//  DataReading - Boolean - flag which indicates the
//    necessity to provide the permission to read
//  data from the directory of temporary files, DataRecording - Boolean - flag which indicates the
//    necessity to provide the permission to record
//  data to the directory of temporary files, Description - String - Description of a reason for which it is required to grant a permission.
//
// Returns:
//  XDTODataObject - internal description of requested permission.
//  Intended only for transfer as a parameter in the function.
//  WorkInSafeMode.QueryOnExternalResourcesUse(),
//  WorkInSafeMode.QueryOnCancelingPermissionsToUseExternalResources()
//  and WorkInSafeMode.QueryOnClearingPermissionToUseExternalResources().
//
Function PermissionToUseTemporaryFilesDirectory(Val DataReading = False, Val DataRecording = False, Val Description = "") Export
	
	Return PermissionToUseFileSystemDirectory(TemporaryFilesDirectoryAlias(), DataReading, DataRecording);
	
EndFunction

// Returns the internal description of the permission to use application directory.
//
// Parameters:
//  DataReading - Boolean - flag which indicates the
//    necessity to provide the permission to
//  read data from application directory, DataRecording - Boolean - flag which indicates the
//    necessity to provide permissions to record
//  data to application directory, Description - String - Description of a reason for which it is required to grant a permission.
//
// Returns:
//  XDTODataObject - internal description of requested permission.
//  Intended only for transfer as a parameter in the function.
//  WorkInSafeMode.QueryOnExternalResourcesUse(),
//  WorkInSafeMode.QueryOnCancelingPermissionsToUseExternalResources()
//  and WorkInSafeMode.QueryOnClearingPermissionToUseExternalResources().
//
Function PermissionToUseApplicationDirectory(Val DataReading = False, Val DataRecording = False, Val Description = "") Export
	
	Return PermissionToUseFileSystemDirectory(ApplicationDirectoryAlias(), DataReading, DataRecording);
	
EndFunction

// Returns the internal description of the permissions to use COM class.
//
// Parameters:
//  ProgID - String - ProgID of the COM class with which it is registered in the system.
//    For
//  example, "Excel.Application", CLSID - String - CLSID of the COM class with which it is registered in the system.
//  ComputerName - String - the name of the computer on which this object is to be created.
//    If the parameter is omitted - object will be created on the computer
//    on which the
//  current workflow is executed, Description - String - Description of a reason for which it is required to grant a permission.
//
// Returns:
//  XDTODataObject - internal description of requested permission.
//  Intended only for transfer as a parameter in the function.
//  WorkInSafeMode.QueryOnExternalResourcesUse(),
//  WorkInSafeMode.QueryOnCancelingPermissionsToUseExternalResources()
//  and WorkInSafeMode.QueryOnClearingPermissionToUseExternalResources().
//
Function PermissionForCOMClassCreation(Val ProgID, Val CLSID, Val ComputerName = "", Val Description = "") Export
	
	Package = WorkInSafeModeService.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "CreateComObject"));
	Result.Description = Description;
	
	Result.ProgId = ProgID;
	Result.CLSID = String(CLSID);
	Result.ComputerName = ComputerName;
	
	Return Result;
	
EndFunction

// Returns the internal description of the permission to
//  use external component supplied in common configuration template.
//
// Parameters:
//  TemplateName - String - name of common template in the configuration with
//    which
//  external component is provided, Description - String - Description of a reason for which it is required to grant a permission.
//
// Return
//  value ObjectXDTO - internal description of requested permission.
//  Intended only for transfer as a parameter in the function.
//  WorkInSafeMode.QueryOnExternalResourcesUse(),
//  WorkInSafeMode.QueryOnCancelingPermissionsToUseExternalResources()
//  and WorkInSafeMode.QueryOnClearingPermissionToUseExternalResources().
//
Function PermissionToUseExternalComponent(Val TemplateName, Val Description = "") Export
	
	Package = WorkInSafeModeService.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "AttachAddin"));
	Result.Description = Description;
	
	Result.TemplateName = TemplateName;
	
	Return Result;
	
EndFunction

// Returns the internal description of the permission to use operating system application.
//
// Parameters:
//  TemplateLaunchRows - String - template of application launch row. See the
//    documentation for
//  the platform, Description - String - Description of a reason for which it is required to grant a permission.
//
// Returns:
//  XDTODataObject - internal description of requested permission.
//  Intended only for transfer as a parameter in the function.
//  WorkInSafeMode.QueryOnExternalResourcesUse(),
//  WorkInSafeMode.QueryOnCancelingPermissionsToUseExternalResources()
//  and WorkInSafeMode.QueryOnClearingPermissionToUseExternalResources().
//
Function PermissionToUseOperatingSystemApplication(Val TemplateLaunchRows, Val Description = "") Export
	
	Package = WorkInSafeModeService.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "RunApplication"));
	Result.Description = Description;
	
	Result.MaskCommand = TemplateLaunchRows;
	
	Return Result;
	
EndFunction

// Returns internal description of the permission to use internet resource.
//
// Parameters:
//  Protocol: Row - protocol through which the interaction with the resource is enabled. Possible
//    values:
//      IMAP,
//      POP3,
//      SMTP,
//      HTTP,
//      HTTPS,
//      FTP,
//      FTPS,
//  Address - String - resource address without indication
//  of the protocol, Port - Number - port number through which interaction with the
//  resource is enabled, Description - String - Description of a reason for which it is required to grant a permission.
//
// Returns:
//  XDTODataObject - internal description of requested permission.
//  Intended only for transfer as a parameter in the function.
//  WorkInSafeMode.QueryOnExternalResourcesUse(),
//  WorkInSafeMode.QueryOnCancelingPermissionsToUseExternalResources()
//  and WorkInSafeMode.QueryOnClearingPermissionToUseExternalResources().
//
Function PermissionForWebsiteUse(Val Protocol, Val Address, Val Port = Undefined, Val Description = "") Export
	
	If Port = Undefined Then
		StandardPorts = StandardInternetProtocolPorts();
		If StandardPorts.Property(Upper(Protocol)) <> Undefined Then
			Port = StandardPorts[Upper(Protocol)];
		EndIf;
	EndIf;
	
	Package = WorkInSafeModeService.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "InternetResourceAccess"));
	Result.Description = Description;
	
	Result.Protocol = Protocol;
	Result.Host = Address;
	Result.Port = Port;
	
	Return Result;
	
EndFunction

// Returns the internal description of the permission on extended data
// management (including setting the priveleged mode) for external modules.
//
// Parameters:
//  Description - String - Description of a reason for which it is required to grant a permission.
//
// Return value: ObjectXDTO - internal description of requested permission.
//  Intended only for transfer as a parameter in the function.
//  WorkInSafeMode.QueryOnExternalResourcesUse(),
//  WorkInSafeMode.QueryOnCancelingPermissionsToUseExternalResources()
//  and WorkInSafeMode.QueryOnClearingPermissionToUseExternalResources().
//
Function PermissionToUsePrivelegedMode(Val Description = "") Export
	
	Package = WorkInSafeModeService.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "ExternalModulePrivilegedModeAllowed"));
	Result.Description = Description;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions-constructors of queries for external resources use.
//

// Creates a request to use external resources.
//
// Parameters:
//  NewPermissions - Array(XDTOObject) - array of XDTOObjects corresponding
//    to the internal descriptions of requested permissions for access to the external resources. It is assumed that
//    all XDTOObjects passed as a parameter are generated using the WorkInSafeMode.Permission*() functions call.
//  Owner - AnyRef - ref to an object of the infobase to
//    which requested permissions are logically connected. For example, all permissions for access to catalogs of
//    files storage volumes are logically connected to the corresponding items of
//    the FilesStorageVolumes catalog. All  permissions for access to catalogs of data
//    exchange (or to other resources depending on the used exchange transport) are logically connected to
//    the corresponding exchange plans nodes etc. If the permission is logically 
// isolated (for example, the grant of permission is regulated by the constant value with the Boolean type) -
//    it is recommended to use reference
//  to an item of the MetadataObjectsIDs catalog, ReplacementMode - Boolean - defines the substitution mode of all previously given permissions for this owner. If
//    the parameter value equals to True, the clearance of all permissions previously
//    requested for the same owner will be added to the query in addition to the requested permissions.
//
// Returns:
//  UUID, reference to query for permissions recorded in IB. After
//  creation of all requests on permissions change, it is required to apply the requested changes by calling the procedure.
//  WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse().
//
Function QueryOnExternalResourcesUse(Val NewPermissions, Val Owner = Undefined, Val ReplacementMode = True) Export
	
	Return WorkInSafeModeService.PermissionChangeRequest(
		Owner,
		ReplacementMode,
		NewPermissions);
	
EndFunction

// Creates a request to cancel permissions for external resources use.
//
// Parameters:
//  Owner - AnyRef - reference to object of infobase which is
//    logically associated with canceled permissions. For example, all permissions for access to directories of
//    files storage volumes are logically associated with the corresponding items in
//    the catalog FilesStorageVolumes, all permissions for access to data exchange directories (or other
//    resources depending on utilized exchange transport) are logically associated with relevant nodes of exchange plans,
//    etc. IN case if the permission is logically isolated (for example, canceled permissions are regulated by constant value with Boolean type) -
//    it is recommended to use reference
//  to an item of the catalog MetadataObjectsIdentifiers, CanceledPermissions - Array(XDTOObject) - array of XDTOObjects corresponding
//    to the internal descriptions of canceled permissions for access to the external resources. It is assumed that
//    all XDTOObjects transferred as parameters are generated by calling the functions WorkInSafeMode.Permission*().
//
// Returns:
//  UUID, reference to query for permissions recorded in IB. After
//  creation of all requests on permissions change, it is required to apply the requested changes by calling the procedure.
//  WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse().
//
Function QueryToCancelPermissionsToUseExternalResources(Val Owner, Val CanceledPermissions) Export
	
	Return WorkInSafeModeService.PermissionChangeRequest(
		Owner,
		False,
		,
		CanceledPermissions);
	
EndFunction

// Creates a query to cancel all permissions to use external resources associated with the owner.
//
// Parameters:
//  Owner - AnyRef - reference to object of infobase which is
//    logically associated with canceled permissions. For example, all permissions for access to directories of
//    files storage volumes are logically associated with the corresponding items in
//    the catalog FilesStorageVolumes, all permissions for access to data exchange directories (or other
//    resources depending on utilized exchange transport) are logically associated with relevant nodes of exchange plans,
//    etc. IN case if the permission is logically isolated (for example, canceled permissions are regulated by constant value with Boolean type) -
//    it is recommended to use reference to an item of the catalog MetadataObjectsIdentifiers.
//
// Returns:
//  UUID, reference to query for permissions recorded in IB. After
//  creation of all requests on permissions change, it is required to apply the requested changes by calling the procedure.
//  WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse().
//
Function QueryOnClearPermissionToUseExternalResources(Val Owner) Export
	
	Return WorkInSafeModeService.PermissionChangeRequest(
		Owner,
		True);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for support of configuration operation with security
// profile in which it is prohibited to connect external modules without setting safe mode.
//

// Checks if safe mode was set while ignoring
//  safe mode of security profile used as security profile with level of configuration privileges.
//
// Return value: Boolean.
//
Function SafeModeIsSet() Export
	
	CurrentSafeMode = SafeMode();
	
	If TypeOf(CurrentSafeMode) = Type("String") Then
		
		If Not TransitionToPrivilegedModeAvailable() Then
			Return True; // It is always possible to switch from unsafe mode to privileged mode.
		EndIf;
		
		Try
			InfobaseProfile = InfobaseSecurityProfile();
		Except
			Return True;
		EndTry;
		
		Return (CurrentSafeMode <> InfobaseProfile);
		
	ElsIf TypeOf(CurrentSafeMode) = Type("Boolean") Then
		
		Return CurrentSafeMode;
		
	EndIf;
	
EndFunction

// Calculates sent expression by tentatively setting safe
//  mode of code execution and safe mode of data separation for all delimiters existing in the configuration.
//  As a result of expression calculation:
//   - attempts to set up privileged mode are ignored,
//   - all external (in relation to platform 1C:Enterprise) actions (COM,
//       external components import, launch of external applications and operating system
//       commands, access to the file system and Internet resources) are prohibited,
//   - it is prohibited to disable the use of session delimiters,
//   - It is prohibited to change values of session delimiters
//       (if separation with this delimiter is not deemed disabled),
//   - It is prohibited to change objects which control the state of conditional separation.
//
// Parameters:
//  Expression - String - expression to
//  be calculated, Parameters - Arbitrary - as a value of this parameter it is
//    possible to transfer the value which is required to calculate expression (in the
//    text of the expression the value must be referred to as the name of the variable Parameters).
//
// Return value: Arbitrary - Expression calculation result.
//
Function EvalInSafeMode(Val Expression, Val Parameters = Undefined) Export
	
	SetSafeMode(True);
	
	DelimitersArray = CommonUseReUse.ConfigurationSeparators();
	
	For Each DelimiterName IN DelimitersArray Do
		
		SetDataSeparationSafeMode(DelimiterName, True);
		
	EndDo;
	
	Return Eval(Expression);
	
EndFunction

// Executes arbitrary algorithm on embedded language of
//  1C:Enterprise tentatively setting safe mode of code execution and safe mode of
//  data separation for all delimiters present in the configuration. As a result of algorithm execution:
//   - attempts to set up privileged mode are ignored,
//   - all external (in relation to platform 1C:Enterprise) actions (COM,
//       external components import, launch of external applications and operating system
//       commands, access to the file system and Internet resources) are prohibited,
//   - it is prohibited to disable the use of session delimiters,
//   - It is prohibited to change values of session delimiters
//       (if separation with this delimiter is not deemed disabled),
//   - It is prohibited to change objects which control the state of conditional separation.
//
// Parameters:
//  Algorithm - String - containing arbitrary algorithm on embedded language of 1C: Enterprise.
//  Parameters - Arbitrary - as a value of this parameter it is
//    possible to transfer the value which is required to execute the algorithm (in
//    the text of this algorithm the value must be referred to as the name of the variable Parameters).
//
Procedure ExecuteInSafeMode(Val Algorithm, Val Parameters = Undefined) Export
	
	SetSafeMode(True);
	
	DelimitersArray = CommonUseReUse.ConfigurationSeparators();
	
	For Each DelimiterName IN DelimitersArray Do
		
		SetDataSeparationSafeMode(DelimiterName, True);
		
	EndDo;
	
	Execute Algorithm;
	
EndProcedure

// Execute the export procedure by name with privileges level of the configuration.
// When enabling security profiles to call operator
// Execute () transfer to safe mode is used with security profile
// used for infobase (if above the stack another safe mode was not set).
// 
// Parameters:
//  MethodName  - String - export procedure name in the
// format <object name>.<procedure name>, where <object name> - this
//                       is a common module or object manager module.
// Parameters  - Array - parameters are sent
//                       to the procedure <ExportProcedureName> in the order of items in the array.
// 
// Example:
//  Parameters = New Array();
//  Parameters.Add("1");
//  WorkInSafeMode.ExecuteConfigurationMethod("MyCommonModule.MyProcedure", Parameters);
//
Procedure ExecuteConfigurationMethod(Val MethodName, Val Parameters = Undefined) Export
	
	Try
		ValidateConfigurationMethodName(MethodName);
	Except
		ErrorInfo = ErrorInfo();
		Raise NStr("en='An error occurred when calling procedure ExecuteConfigurationMethod of common module WorkInSafeMode.';ru='Ошибка при вызове процедуры ВыполнитьМетодКонфигурации общего модуля РаботаВБезопасномРежиме.'")
			+ Chars.LF + BriefErrorDescription(ErrorInfo);
	EndTry;
	
	If GetFunctionalOption("SecurityProfilesAreUsed") AND Not SafeModeIsSet() Then
		
		InfobaseProfile = InfobaseSecurityProfile();
		
		If ValueIsFilled(InfobaseProfile) Then
			
			SetSafeMode(InfobaseProfile);
			If SafeMode() = True Then
				SetSafeMode(False);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ParametersString = "";
	If Parameters <> Undefined AND Parameters.Count() > 0 Then
		For IndexOf = 0 To Parameters.UBound() Do 
			ParametersString = ParametersString + "Parameters[" + IndexOf + "],";
		EndDo;
		ParametersString = Mid(ParametersString, 1, StrLen(ParametersString) - 1);
	EndIf;
	
	Execute MethodName + "(" + ParametersString + ")";
	
EndProcedure

// Execute exporting procedure of the object of embedded language by name.
// When enabling security profiles to call operator
// Execute () transfer to safe mode is used with security profile
// used for infobase (if above the stack another safe mode was not set).
//
// Parameters:
//  Object - Arbitrary - object of embedded language of 1C:Enterprise containing
//  methods (for example, DataProcessorObject), MethodName - String - name of export procedure of processing object module.
// Parameters - Array - parameters are sent
//  to the procedure <ProcedureName> in the order of items in the array.
//
Procedure ExecuteObjectMethod(Val Object, Val MethodName, Val Parameters = Undefined) Export
	
	// Method name check for correctness.
	Try
		Test = New Structure(MethodName, MethodName);
	Except
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Incorrect parameter value MethodName (%1)';ru='Некорректное значение параметра ИмяМетода (%1)'"),
			MethodName);
	EndTry;
	
	If GetFunctionalOption("SecurityProfilesAreUsed") AND Not SafeModeIsSet() Then
		
		InfobaseProfile = InfobaseSecurityProfile();
		
		If ValueIsFilled(InfobaseProfile) Then
			
			SetSafeMode(InfobaseProfile);
			If SafeMode() = True Then
				SetSafeMode(False);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ParametersString = "";
	If Parameters <> Undefined AND Parameters.Count() > 0 Then
		For IndexOf = 0 To Parameters.UBound() Do 
			ParametersString = ParametersString + "Parameters[" + IndexOf + "],";
		EndDo;
		ParametersString = Mid(ParametersString, 1, StrLen(ParametersString) - 1);
	EndIf;
	
	Execute "Object." + MethodName + "(" + ParametersString + ")";
	
EndProcedure

// Verifies that transferred name is the name of configuration export procedure.
// Can be used to check that transferred string does not
// contain arbitrary algorithm on embedded language of 1C:Enterprise before using it in
// the operators Execute () and Calculate () when they are used for dynamic call of configuration code methods.
//
// IN case if transferred string does not correspond to configuration method name - being generated.
//
Procedure ValidateConfigurationMethodName(Val MethodName) Export
	
	// Check preconditions for the format ExportProcedureName.
	NameParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(MethodName, ".");
	If NameParts.Count() <> 2 AND NameParts.Count() <> 3 Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Wrong parameter format MethodName (%1)';ru='Неправильный формат параметра ИмяМетода (%1)'"),
			MethodName);
	EndIf;
	
	ObjectName = NameParts[0];
	If NameParts.Count() = 2 AND Metadata.CommonModules.Find(ObjectName) = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Wrong format of the
		|parameter MethodName (%1): General module ""%2"" is not found.';ru='Неправильный
		|формат параметра ИмяМетода (%1): Не найден общий модуль ""%2"".'"),
			MethodName,
			ObjectName);
	EndIf;
	
	If NameParts.Count() = 3 Then
		FullObjectName = NameParts[0] + "." + NameParts[1];
		Try
			Manager = ObjectManagerByName(FullObjectName);
		Except
			Manager = Undefined;
		EndTry;
		If Manager = Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Incorrect format of
		|the parameter MethodName (%1): manager of the object ""%2"" is not found.';ru='Неправильный
		|формат параметра ИмяМетода (%1): Не найден менеджер объекта ""%2"".'"),
				MethodName,
				FullObjectName);
		EndIf;
	EndIf;
	
	ObjectMethodName = NameParts[NameParts.UBound()];
	TempStructure = New Structure;
	Try
		// Check whether ObjectMethodName is a valid identifier.
		// For example: MyProcedure
		TempStructure.Insert(ObjectMethodName);
	Except
		WriteLogEvent(NStr("en='Safe method execution';ru='Безопасное выполнение метода'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Incorrect format of
		|parameter MethodName (%1): Method name ""%2"" does not correspond to the requirements of generation of procedures and functions names.';ru='Неправильный
		|формат параметра ИмяМетода (%1): Имя метода ""%2"" не соответствует требованиям образования имен процедур и функций.'"),
			MethodName,
			ObjectMethodName);
	EndTry;
	
EndProcedure

// Checks the possibility to enable handlers of session parameters setup.
//
// If with current settings of security profiles (in the cluster of servers and
// in infobase) it is impossible to execute handlers of session parameters setup - an
// exception is generated that contains description of the cause
// for which it is impossible to execute handlers of session parameters setup and the list of actions that can be taken to remove this cause.
//
Procedure CheckPossibilityToExecuteSessionSettingsSetupHandlers() Export
	
	If CommonUse.FileInfobase(InfobaseConnectionString()) Then
		Return;
	EndIf;
	
	InfobaseProfile = InfobaseSecurityProfile();
	
	If GetFunctionalOption("SecurityProfilesAreUsed") AND ValueIsFilled(InfobaseProfile) Then
		
		// Information base is configured for use with security profile
		// in which full access to external modules is prohibited.
		
		SetSafeMode(InfobaseProfile);
		If SafeMode() <> InfobaseProfile Then
			
			// IB profile is not available for handlers.
			
			SetSafeMode(False);
			
			If PossibleToExecuteSessionParametersSetupHandlersWithoutSafeModeInstallation() Then
				
				Return;
				
			Else
				
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Cannot execute handlers of session parameters setup due to: security profile %1 is absent in servers cluster of 1C:Enterprise or it is prohibited to use it as security profile of safe mode.
		|
		|For restoration of the application it is required to disable the use of security profile through the cluster console and reconfigure security profiles using configuration interface (corresponding commands are located in the section of application settings';ru='Невозможно выполнение обработчиков установки параметров сеанса по причине: профиль безопасности %1 отсутствует в кластере серверов 1С:Предприятия, или для него запрещено использование в качестве профиля безопасности безопасного режима.
		|
		|Для восстановления работоспособности программы требуется отключить использование профиля безопасности через консоль кластера и заново настроить профили безопасности с помощью интерфейса конфигурации (соответствующие команды находятся в разделе настроек программы).'"),
					InfobaseProfile);
				
			EndIf;
			
		EndIf;
		
		PrivilegedModeAvailable = TransitionToPrivilegedModeAvailable();
		
		SetSafeMode(False);
		
		If Not PrivilegedModeAvailable Then
			
			// Profile of IB is available for execution of handlers, but it is impossible to set privileged mode.
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='It is impossible to execute handlers of session parameters setup due to: security profile %1 does not contain a permission to set privileged mode. It may have been edited through the cluster console.
		|
		|For restoration of the application it is required to disable the use of security profile through the cluster console and reconfigure security profiles using configuration interface (corresponding commands are located in the section of application settings';ru='Невозможно выполнение обработчиков установки параметров сеанса по причине: профиль безопасности %1 не содержит разрешения на установку привилегированного режима. Возможно, он был отредактирован через консоль кластера.
		|
		|Для восстановления работоспособности программы требуется отключить использование профиля безопасности через консоль кластера и заново настроить профили безопасности с помощью интерфейса конфигурации (соответствующие команды находятся в разделе настроек программы).'"),
				InfobaseProfile);
			
		EndIf;
		
	Else
		
		// Information base is not configured for use with security
		// profile in which full access to external modules is prohibited.
		
		Try
			
			PrivilegedModeAvailable = Eval("TransitionToPrivilegedModeAvailable()");
			
		Except
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Cannot execute handlers of session parameters setup due to: %1.
		|
		|Maybe a security profile was set for infobase through the cluster console which does not allow to execute external modules without setup of safe mode. IN this case, to restore application operation, it is required to disable the use of security profile through the cluster console and reconfigure security profiles using configuration interface (corresponding commands are located in the section of application settings).At the same time, the application will be automatically configured for shared use with enabled security profiles.';ru='Невозможно выполнение обработчиков установки параметров сеанса по причине: %1.
		|
		|Возможно, для информационной базы через консоль кластера был установлен профиль безопасности, не допускающий выполнения внешних модулей без установки безопасного режима. В этом случае для восстановления работоспособности программы требуется отключить использование профиля безопасности через консоль кластера и заново настроить профили безопасности с помощью интерфейса конфигурации (соответствующие команды находятся в разделе настроек программы).При этом программа будет автоматически корректно настроена на использование совместно с включенными профилями безопасности.'"),
				BriefErrorDescription(ErrorInfo())
			);
			
		EndTry;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other
//

// Creates the requests for update of configuration permissions.
//
// Parameters:
//  IncludingIBProfileCreationRequest - Boolean - include in the results the request
//    to create a security profile for current infobase.
//
// Return value: Array (UUID) - the identifiers of
// the requests for the update of the configuration permissions to the required level.
//
Function ConfigurationPermissionsUpdateQueries(Val IncludingIBProfileCreationRequest = True) Export
	
	Return WorkInSafeModeService.ConfigurationPermissionsUpdateQueries(IncludingIBProfileCreationRequest);
	
EndFunction

// Returns the control amounts of the files belonging to the external component kit which is delivered in the configuration template.
//
// Parameters:
//  TemplateName - String - name of the configuration template which contains a set of external components.
//
// Returns - FixedMap:
//                         * Key - String - file
//                         name, * Value - String - control amount.
//
Function ExternalComponentsKitFilesControlSums(Val TemplateName) Export
	
	Return WorkInSafeModeService.ExternalComponentsKitFilesControlSums(TemplateName);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns an object manager by name.
// Limitation: route points of business processes are not processed.
//
// Parameters:
//  Name - String - name, such as "Catalog", "Catalogs", "Catalog.Companies".
//
// Returns:
//  CatalogsManager, CatalogManager, DocumentsManager, DocumentManager, ...
// 
Function ObjectManagerByName(Name)
	Var MOClass, MOName, Manager;
	
	NameParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Name, ".");
	
	If NameParts.Count() > 0 Then
		MOClass = Upper(NameParts[0]);
	EndIf;
	
	If NameParts.Count() > 1 Then
		MOName = NameParts[1];
	EndIf;
	
	If      MOClass = "EXCHANGEPLAN"
	 Or      MOClass = "EXCHANGEPLANS" Then
		Manager = ExchangePlans;
		
	ElsIf MOClass = "CATALOG"
	      Or MOClass = "CATALOGS" Then
		Manager = Catalogs;
		
	ElsIf MOClass = "DOCUMENT"
	      Or MOClass = "DOCUMENTS" Then
		Manager = Documents;
		
	ElsIf MOClass = "DOCUMENTJOURNAL"
	      Or MOClass = "DOCUMENTSJOURNALS" Then
		Manager = DocumentJournals;
		
	ElsIf MOClass = "ENUM"
	      Or MOClass = "ENUMS" Then
		Manager = Enums;
		
	ElsIf MOClass = "REPORT"
	      Or MOClass = "REPORTS" Then
		Manager = Reports;
		
	ElsIf MOClass = "DATAPROCESSOR"
	      Or MOClass = "DATAPROCESSORS" Then
		Manager = DataProcessors;
		
	ElsIf MOClass = "CHARTOFCHARACTERISTICTYPES"
	      Or MOClass = "CHARTSOFCHARACTERISTICTYPES" Then
		Manager = ChartsOfCharacteristicTypes;
		
	ElsIf MOClass = "CHARTOFACCOUNTS"
	      Or MOClass = "CHARTSOFACCOUNTS" Then
		Manager = ChartsOfAccounts;
		
	ElsIf MOClass = "CHARTOFCALCULATIONTYPES"
	      Or MOClass = "CHARTSOFCALCULATIONTYPES" Then
		Manager = ChartsOfCalculationTypes;
		
	ElsIf MOClass = "INFORMATIONREGISTER"
	      Or MOClass = "INFORMATIONREGISTERS" Then
		Manager = InformationRegisters;
		
	ElsIf MOClass = "ACCUMULATIONREGISTER"
	      Or MOClass = "ACCUMULATIONREGISTERS" Then
		Manager = AccumulationRegisters;
		
	ElsIf MOClass = "ACCOUNTINGREGISTER"
	      Or MOClass = "ACCOUNTINGREGISTERS" Then
		Manager = AccountingRegisters;
		
	ElsIf MOClass = "CALCULATIONREGISTER"
	      Or MOClass = "CALCULATIONREGISTERS" Then
		
		If NameParts.Count() < 3 Then
			// Calculation register
			Manager = CalculationRegisters;
		Else
			ClassSubordinateOM = Upper(NameParts[2]);
			If NameParts.Count() > 3 Then
				NameOfSlave = NameParts[3];
			EndIf;
			If ClassSubordinateOM = "RECALCULATION"
			 Or ClassSubordinateOM = "RECALCULATIONS" Then
				// Recalculation
				Try
					Manager = CalculationRegisters[MOName].Recalculations;
					MOName = NameOfSlave;
				Except
					Manager = Undefined;
				EndTry;
			EndIf;
		EndIf;
		
	ElsIf MOClass = "BUSINESSPROCESS"
	      Or MOClass = "BUSINESSPROCESSES" Then
		Manager = BusinessProcesses;
		
	ElsIf MOClass = "TASK"
	      Or MOClass = "TASKS" Then
		Manager = Tasks;
		
	ElsIf MOClass = "CONSTANT"
	      Or MOClass = "CONSTANTS" Then
		Manager = Constants;
		
	ElsIf MOClass = "SEQUENCE"
	      Or MOClass = "SEQUENCES" Then
		Manager = Sequences;
	EndIf;
	
	If Manager <> Undefined Then
		If ValueIsFilled(MOName) Then
			Try
				Return Manager[MOName];
			Except
				Manager = Undefined;
			EndTry;
		Else
			Return Manager;
		EndIf;
	EndIf;
	
	Raise StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Failed to get a manager for the object ""%1""';ru='Не удалось получить менеджер для объекта ""%1""'"), Name);
	
EndFunction

// Checks the possibility to execute handlers of session parameters setup without setting safe mode.
//
// Return value: Boolean.
//
Function PossibleToExecuteSessionParametersSetupHandlersWithoutSafeModeInstallation() Export
	
	Try
		
		Result = Eval("TransitionToPrivilegedModeAvailable()");
		Return Result;
		
	Except
		
		WriteLogEventTemplate = NStr("en='During installation of session parameters an error occurred: -------------------------------------------------------------------------------------------- %1 -------------------------------------------------------------------------------------------- Launch of the application is not possible.';ru='При установке параметров сеанса произошла ошибка: -------------------------------------------------------------------------------------------- %1 -------------------------------------------------------------------------------------------- Запуск программы будет невозможен.'");
		
		WriteLogEventText = StringFunctionsClientServer.PlaceParametersIntoString(
			WriteLogEventTemplate, DetailErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
			NStr("en='Session parameters setup';ru='Установка параметров сеанса'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			,
			,
			WriteLogEventText);
		
		Return False;
		
	EndTry;
	
EndFunction

// Checks the possibility to switch from current safe mode to privileged mode.
//
// Return value: Boolean.
//
Function TransitionToPrivilegedModeAvailable()
	
	SetPrivilegedMode(True);
	Return PrivilegedMode();
	
EndFunction

// Returns the name of security profile which provides privileges for configuration code.
//
// Return value: String - security proattachment file name.
//
Function InfobaseSecurityProfile()
	
	SetPrivilegedMode(True);
	
	Return Constants.InfobaseSecurityProfile.Get();
	
EndFunction

// Returns "predefined" alias for application directory.
//
// Return value: String.
//
Function ApplicationDirectoryAlias()
	
	Return "/bin";
	
EndFunction

// Returns "predefined" alias for the directory of temporary files.
//
Function TemporaryFilesDirectoryAlias()
	
	Return "/temp";
	
EndFunction

// Returns standard network ports for internet protocols, tools
//  for which exist in the embedded language of 1C: Enterprise. Used to determine the network
//  port in cases when permission is requested from the application code without indication of network port.
//
// Return value: FixedStructure:
//                          * Key - String,
//                          Internet Protocol name, * Value - Figure, number of network port.
//
Function StandardInternetProtocolPorts()
	
	Result = New Structure();
	
	Result.Insert("IMAP",  143);
	Result.Insert("POP3",  110);
	Result.Insert("SMTP",  25);
	Result.Insert("HTTP",  80);
	Result.Insert("HTTPS", 443);
	Result.Insert("FTP",   21);
	Result.Insert("FTPS",  21);
	
	Return New FixedStructure(Result);
	
EndFunction

#EndRegion

