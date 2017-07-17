////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of common use:
// - Support of security profiles.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Use of security profile.
//

// Returns to URI the name spaces of XDTO
// package which is used for description of the permissions in the security profiles.
//
// Return value: String, URI name spaces of XDTO package.
//
Function Package() Export
	
	Return Metadata.XDTOPackages.ApplicationPermissions_1_0_0_1.Namespace;
	
EndFunction

// Checks the possibility to use the security profiles for current infobase.
//
// Return value: Boolean.
//
Function SecurityProfilesCanBeUsed() Export
	
	If CommonUse.FileInfobase(InfobaseConnectionString()) Then
		Return False;
	EndIf;
	
	Cancel = False;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\WhenCheckingSecurityProfilesUsePossibility");
	For Each Handler IN EventHandlers Do
		Handler.Module.WhenCheckingSecurityProfilesUsePossibility(Cancel);
		If Cancel Then
			Break;
		EndIf;
	EndDo;
	
	WorkInSafeModeOverridable.WhenCheckingSecurityProfilesUsePossibility(Cancel);
	
	Return Not Cancel;
	
EndFunction

// Checks the possibility to setup the security profiles from current infobase.
//
// Return value: Boolean.
//
Function SecurityProfilesSetupAvailable() Export
	
	If SecurityProfilesCanBeUsed() Then
		
		Cancel = False;
		
		EventHandlers = CommonUse.ServiceEventProcessor(
			"StandardSubsystems.BasicFunctionality\WhenCheckingPossibilityToSetupSecurityProfiles");
		
		For Each Handler IN EventHandlers Do
			Handler.Module.WhenCheckingPossibilityToSetupSecurityProfiles(Cancel);
			If Cancel Then
				Break;
			EndIf;
		EndDo;
		
		If Not Cancel Then
			WorkInSafeModeOverridable.WhenCheckingPossibilityToSetupSecurityProfiles(Cancel);
		EndIf;
		
		Return Not Cancel;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

// Performs additional (defined by business logic)
//  actions when the use of security profiles is enabled.
//
Procedure OnSwitchUsingSecurityProfiles() Export
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnSwitchUsingSecurityProfiles");
	For Each Handler IN EventHandlers Do
		Handler.Module.OnSwitchUsingSecurityProfiles();
	EndDo;
	
	WorkInSafeModeOverridable.OnSwitchUsingSecurityProfiles();
	
EndProcedure

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
	
	Result = New Map();
	
	NameStructure = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(TemplateName, ".");
	
	If NameStructure.Count() = 2 Then
		
		// This is a common template
		Template = GetCommonTemplate(NameStructure[1]);
		
	ElsIf NameStructure.Count() = 4 Then
		
		// This is a template of metadata object.
		ObjectManager = CommonUse.ObjectManagerByFullName(NameStructure[0] + "." + NameStructure[1]);
		Template = ObjectManager.GetTemplate(NameStructure[3]);
		
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to generate a permission to use
		|an external component: incorrect template name %1!';ru='Не удалось сформировать разрешение
		|на использование внешней компоненты: некорректное имя макета %1!'"), TemplateName);
	EndIf;
	
	If Template = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to generate the permission to use
		|the external component delivered with the template 1%: template% 1 is not found in the configuration content!';ru='Не удалось сформировать разрешение
		|на использование внешней компоненты, поставляемой в макете %1: макет %1 не обнаружден в составе конфигурации!'"), TemplateName);
	EndIf;
	
	If Metadata.FindByFullName(TemplateName).TemplateType <> Metadata.ObjectProperties.TemplateType.BinaryData Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to generate a permission for the
		|use of the external component: template %1 does not contain binary data!';ru='Не удалось сформировать разрешение
		|на использование внешней компоненты: макет %1 не содержит двоичных данных!'"), TemplateName);
	EndIf;
	
	TempFile = GetTempFileName("zip");
	Template.Write(TempFile);
	
	Archiver = New ZipFileReader(TempFile);
	UnpackingCatalog = GetTempFileName() + "\";
	CreateDirectory(UnpackingCatalog);
	
	ManifestFile = "";
	For Each ArchiveItem IN Archiver.Items Do
		If Upper(ArchiveItem.Name) = "MANIFEST.XML" Then
			ManifestFile = UnpackingCatalog + ArchiveItem.Name;
			Archiver.Extract(ArchiveItem, UnpackingCatalog);
		EndIf;
	EndDo;
	
	If IsBlankString(ManifestFile) Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to generate the permission to use
		|the external component delivered with the template %1: file MANIFEST.XML is not found in the archive!';ru='Не удалось сформировать разрешение
		|на использование внешней компоненты, поставляемой в макете %1: в архиве не обнаружен файл MANIFEST.XML!'"), TemplateName);
	EndIf;
	
	ReadStream = New XMLReader();
	ReadStream.OpenFile(ManifestFile);
	KitDescription = XDTOFactory.ReadXML(ReadStream, XDTOFactory.Type("http://v8.1c.ru/8.2/addin/bundle", "bundle"));
	For Each ComponentDescription IN KitDescription.component Do
		
		If ComponentDescription.type = "native" OR ComponentDescription.type = "com" Then
			
			FileComponents = UnpackingCatalog + ComponentDescription.path;
			
			Archiver.Extract(Archiver.Items.Find(ComponentDescription.path), UnpackingCatalog);
			
			Hashing = New DataHashing(HashFunction.SHA1);
			Hashing.AppendFile(FileComponents);
			
			HashSum = Hashing.HashSum;
			HashSumConvertedToStringBase64 = Base64String(HashSum);
			
			Result.Insert(ComponentDescription.path, HashSumConvertedToStringBase64);
			
		EndIf;
		
	EndDo;
	
	ReadStream.Close();
	Archiver.Close();
	
	Try
		DeleteFiles(UnpackingCatalog);
	Except
		// Processing of the exception is not required.
	EndTry;
	
	Try
		DeleteFiles(TempFile);
	Except
		// Processing of the exception is not required.
	EndTry;
	
	Return New FixedMap(Result);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Conversion of links to the form
// Type+Identifier for storage in the permissions registers.
//
// Used custom Method storage links because. for the registers
// of permissions the referential integrity is not required, there is
// also no need to delete records from the registers together with an object.
//

// Forms the parameters for reference storage in permissions registers.
//
// Parameters:
//  Refs - AnyRef.
//
// Return value: Structure:
//                        * Type - CatalogRef.MetadataObjectsIdentifiers,
//                        * Identifier - UUID - unique
//                           ref identifier.
//
Function PropertiesForPermissionsRegister(Val Refs) Export
	
	Result = New Structure("Type,ID");
	
	If Refs = Catalogs.MetadataObjectIDs.EmptyRef() Then
		
		Result.Type = Catalogs.MetadataObjectIDs.EmptyRef();
		Result.ID = New UUID("00000000-0000-0000-0000-000000000000");
		
	Else
		
		Result.Type = CommonUse.MetadataObjectID(Refs.Metadata());
		Result.ID = Refs.UUID();
		
	EndIf;
	
	Return Result;
	
EndFunction

// Generates a reference from data stored in permissions registers.
//
// Parameters:
//  Type - CatalogRef.MetadataObjectIdentifier,
//  Identifier - UUID - unique reference identifier.
//
// Return value: AnyRef.
//
Function RefFromPermissionsRegister(Val Type, Val ID) Export
	
	If Type = Catalogs.MetadataObjectIDs.EmptyRef() Then
		Return Type;
	Else
		
		MetadataObject = CommonUse.MetadataObjectByID(Type);
		Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
		
		If IsBlankString(ID) Then
			Return Manager.EmptyRef();
		Else
			Return Manager.GetRef(ID);
		EndIf;
		
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Creating permissions queries.
//

// Creates a request to change the permissions to use external resources.
// Only for internal use.
//
// Parameters:
//  Owner - AnyRef - owner of permissions for use of external resources.
//    (Undefined when permissions are requested for the configuration, not
//  for configuration objects), ReplacementMode - Boolean - replacement mode of previously granted
//  permissions for the owner, AddedPermissions - Array(XDTOObject) - array of XDTOObjects corresponding
//    to the internal descriptions of requested permissions for access to the external resources. It is assumed that
//    all XDTOObjects transferred as parameters were generated by the
//  function call WorkInSafeMode.Permission*(), DeletedPermissions - Array(XDTOObject) - array of XDTOObjects corresponding
//    to the internal descriptions of canceled permissions for access to the external resources. It is assumed that
//    all XDTOObjects transferred as parameters were generated by the
//  function call WorkInSafeMode.Permission*(), ExternalModule - AnyRef - reference corresponding to the external module
//    for which permissions are requested. (Undefined when the permissions for a configuration are requested, not for external modules).
//
// Returns - UUID - identifier of created request.
//
Function PermissionChangeRequest(Val Owner, Val ReplacementMode, Val PermissionsToBeAdded = Undefined, Val PermissionsToBeDeleted = Undefined, Val ApplicationModule = Undefined) Export
	
	StandardProcessing = True;
	Result = Undefined;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\WhenPermissionsForExternalResourcesUseAreRequested");
	For Each Handler IN EventHandlers Do
		
		Handler.Module.WhenPermissionsForExternalResourcesUseAreRequested(
			ApplicationModule, Owner, ReplacementMode, PermissionsToBeAdded, PermissionsToBeDeleted, StandardProcessing, Result);
		
		If Not StandardProcessing Then
			Break;
		EndIf;
		
	EndDo;
	
	If StandardProcessing Then
		
		WorkInSafeModeOverridable.WhenPermissionsForExternalResourcesUseAreRequested(
			ApplicationModule, Owner, ReplacementMode, PermissionsToBeAdded, PermissionsToBeDeleted, StandardProcessing, Result);
		
	EndIf;
	
	If StandardProcessing Then
		
		Result = InformationRegisters.PermissionQueriesOnUseExternalResources.PermissionsUseRequest(
			ApplicationModule, Owner, ReplacementMode, PermissionsToBeAdded, PermissionsToBeDeleted);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Creates requests to use external resources for the external module.
//
// Parameters:
//  ExternalModule - AnyRef - a reference corresponding to the external module
//  for which permissions are requested, NewPermissions - Array(XDTOObject) - array of XDTOObjects corresponding
//    to the internal descriptions of requested permissions for access to the external resources. It is assumed that
//    all XDTOObjects transferred as parameters are generated by calling the functions WorkInSafeMode.Permission*().
//    When permissions are requested for the external modules, they are always added in replacement mode.
//
// Returns - Array(UUID) - identifiers of created requests.
//
Function PermissionsRequestForExternalModule(Val ApplicationModule, Val NewPermissions = Undefined) Export
	
	Result = New Array();
	
	If NewPermissions = Undefined Then
		NewPermissions = New Array();
	EndIf;
	
	If NewPermissions.Count() > 0 Then
		
		// If the security profile still does not exist- it shall be created.
		If ExternalModuleConnectionMode(ApplicationModule) = Undefined Then
			Result.Add(SecurityProfileCreationRequest(ApplicationModule));
		EndIf;
		
		Result.Add(
			PermissionChangeRequest(
				ApplicationModule, True, NewPermissions, Undefined, ApplicationModule
			)
		);
		
	Else
		
		// If security profile exists - it shall be deleted.
		If ExternalModuleConnectionMode(ApplicationModule) <> Undefined Then
			Result.Add(SecurityProfileDeletionRequest(ApplicationModule));
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Creates a request to create the security profile for an external module.
// Only for internal use.
//
// Parameters:
//  ExternalModule - AnyRef - reference corresponding to the external module
//    for which permissions are requested. (Undefined when the permissions for a configuration are requested, not for external modules).
//
// Returns - UUID - identifier of created request.
//
Function SecurityProfileCreationRequest(Val ApplicationModule) Export
	
	StandardProcessing = True;
	Result = Undefined;
	Operation = Enums.OperationsAdministrationSecurityProfiles.Creating;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\WhenSecurityProfileCreationIsRequested");
	For Each Handler IN EventHandlers Do
		
		Handler.Module.WhenSecurityProfileCreationIsRequested(
			ApplicationModule, StandardProcessing, Result);
		
		If Not StandardProcessing Then
			Break;
		EndIf;
		
	EndDo;
	
	If StandardProcessing Then
		WorkInSafeModeOverridable.WhenSecurityProfileCreationIsRequested(
			ApplicationModule, StandardProcessing, Result);
	EndIf;
	
	If StandardProcessing Then
		
		Result = InformationRegisters.PermissionQueriesOnUseExternalResources.PermissionsAdministrationRequest(
			ApplicationModule, Operation);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Creates a request for the deletion of the security profile for external module.
// Only for internal use.
//
// Parameters:
//  ExternalModule - AnyRef - reference corresponding to the external module
//    for which permissions are requested. (Undefined when the permissions for a configuration are requested, not for external modules).
//
// Returns - UUID - identifier of created request.
//
Function SecurityProfileDeletionRequest(Val ApplicationModule) Export
	
	StandardProcessing = True;
	Result = Undefined;
	Operation = Enums.OperationsAdministrationSecurityProfiles.Delete;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\WhenSecurityProfileDeletionIsRequested");
	For Each Handler IN EventHandlers Do
		
		Handler.Module.WhenSecurityProfileDeletionIsRequested(
			ApplicationModule, StandardProcessing, Result);
		
		If Not StandardProcessing Then
			Break;
		EndIf;
		
	EndDo;
	
	If StandardProcessing Then
		WorkInSafeModeOverridable.WhenSecurityProfileDeletionIsRequested(
			ApplicationModule, StandardProcessing, Result);
	EndIf;
	
	If StandardProcessing Then
		
		Result = InformationRegisters.PermissionQueriesOnUseExternalResources.PermissionsAdministrationRequest(
			ApplicationModule, Operation);
		
	EndIf;
	
	Return Result;
	
EndFunction

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
	
	Result = New Array();
	
	BeginTransaction();
	
	Try
		
		If IncludingIBProfileCreationRequest Then
			Result.Add(SecurityProfileCreationRequest(Catalogs.MetadataObjectIDs.EmptyRef()));
		EndIf;
		
		EventHandlers = CommonUse.ServiceEventProcessor(
			"StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources");
		For Each Handler IN EventHandlers Do
			Handler.Module.WhenFillingOutPermitsForAccessToExternalResources(Result);
		EndDo;
		
		WorkInSafeModeOverridable.WhenFillingOutPermitsForAccessToExternalResources(Result);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Application of permissions requests to use the external resources.
//

// Displays the permissions for external resources use by the tables of permissions.
//
// Parameters:
//  Tables - Structure - permissions table for which
//    the representation is formed (see PermissionsTables()).
//
// Return value: SpreadsheetDocument, display of the permissions for the use of external resources.
//
Function PermissionPresentationForExternalResourcesUse(Val SoftwareModuleType, Val SoftwareModuleID, Val OwnerType, Val IDOwner, Val permissions) Export
	
	BeginTransaction();
	
	ApplicationModule = RefFromPermissionsRegister(SoftwareModuleType, SoftwareModuleID);
	DataProcessors.PermissionSettingsForExternalResourcesUse.ClearGivenPermissions(ApplicationModule, False);
	
	Manager = DataProcessors.PermissionSettingsForExternalResourcesUse.Create();
	
	Manager.AddRequestForExternalResourcesUsePermissions(
			SoftwareModuleType,
			SoftwareModuleID,
			OwnerType,
			IDOwner,
			True,
			permissions,
			New Array());
	
	Manager.CalculateQueriesApplication();
	
	RollbackTransaction();
	
	Return Manager.Presentation(True);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// External modules
//

// Returns the connection mode of the external module.
//
// Parameters:
//  ExternalModule - AnyRef, a reference corresponding to an external
//    module for which the connection mode is requested.
//
// Return value: String - name of a security profile which shall
//  be used for connection of an external module. If the connection mode is not registered for external module - returns Undefined.
//
Function ExternalModuleConnectionMode(Val ExternalModule) Export
	
	Return InformationRegisters.ExternalModulesConnectionModes.ExternalModuleConnectionMode(ExternalModule);
	
EndFunction

// Returns the software module that performs the functions of external module manager.
//
//  ExternalModule - AnyRef, a reference corresponding to the external
//    module for which you request a manager.
//
// Return value: CommonModule.
//
Function ExternalModuleManager(Val ExternalModule) Export
	
	Containers = New Array();
	
	Managers = ExternalModulesManagers();
	For Each Manager IN Managers Do
		ManagerContainers = Manager.ExternalModulesContainers();
		
		If TypeOf(ExternalModule) = Type("CatalogRef.MetadataObjectIDs") Then
			MetadataObject = CommonUse.MetadataObjectByID(ExternalModule);
		Else
			MetadataObject = ExternalModule.Metadata();
		EndIf;
		
		If ManagerContainers.Find(MetadataObject) <> Undefined Then
			Return Manager;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Control of service data recording.
//

// The procedure should be called when any service data is
// recorded, and the data can not be changed in the specified safe mode.
//
Procedure OnWriteServiceData(Object) Export
	
	If WorkInSafeMode.SafeModeIsSet() Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Writing of object %1 is unavailable: safe mode is set: %2.';ru='Запись объекта %1 недоступна: установлен безопасный режим: %2!'"),
			Object.Metadata().FullName(),
			SafeMode()
		);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Declaration of application events handlers.
//

// See details of the same procedure in the StandardSubsystemsServer module.
//
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ServerHandlers["StandardSubsystems.ReportsVariants\OnConfiguringOptionsReports"].Add(
			"WorkInSafeModeService");
	EndIf;
	
	// CLIENT HANDLERS.
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\AfterSystemOperationStart"].Add(
			"PermissionSettingOnExternalResourcesUsageClient");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of service events.
//

// Contains the settings of reports variants placement in reports panel.
//
// Parameters:
//   Settings - Collection - Used for the description of reports
//       settings and options, see description to ReportsVariants.ConfigurationReportVariantsSetupTree().
//
// Description:
//  See ReportsVariantsOverride.SetupReportsVariants().
//
Procedure OnConfiguringOptionsReports(Settings) Export
	ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
	ModuleReportsVariants.SetReportInManagerModule(Settings, Metadata.Reports.UsedExternalResources);
EndProcedure

// Fills the structure of the parameters required
// for functioning of the client code at the configuration start. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddClientWorkParametersOnStart(Parameters) Export
	
	SetPrivilegedMode(True);
	
	Parameters.Insert("ShowPermissionsSetupAssistant", PermissionsRequestInteractiveModeIsUsed());
	
	If Parameters.ShowPermissionsSetupAssistant Then
		
		If Users.InfobaseUserWithFullAccess() Then
			
			Checking = PermissionSettingOnExternalResourcesUsageServerCall.CheckPermissionsToUseExternalResources();
			
			If Checking.CheckResult Then
				
				Parameters.Insert("ValidatePermissionToUseExternalResourcesApplication", False);
				
			Else
				
				Parameters.Insert("ValidatePermissionToUseExternalResourcesApplication", True);
				Parameters.Insert("PermissionToUseExternalResourcesApplicationCheck", Checking);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Declaration of application events.
//

// Announces service events of
//  the subsystem BasicFunctionality intended for support of the security profiles.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Appears when the possibility of security profiles use is checked.
	//
	// Parameters:
	//  Cancel - Boolean. If the use of security profiles is not available for infobase -
	//    value of this parameter shall be set to True.
	//
	// Syntax:
	// Procedure WhenSecurityProfilesUsePossibilityIsChecked (Failure) Export
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\WhenCheckingSecurityProfilesUsePossibility");
	
	// Appears when the possibilty of security profile setup is checked.
	//
	// Parameters:
	//  Cancel - Boolean. If the use of security profiles is not available for infobase -
	//    value of this parameter shall be set to True.
	//
	// Syntax:
	// Procedure WhenSecurityProfilesSetupPossibilityIsChecked (Failure) Export
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\WhenCheckingPossibilityToSetupSecurityProfiles");
	
	// Appears when you enable the use of the infobase for security profiles.
	//
	// Syntax:
	// Procedure WhenSecurityProfileUseIsSwitchedOn() Export
	//
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\OnSwitchUsingSecurityProfiles");
	
	// Fills out a list of queries for external permissions that must be provided when creating an infobase or updating a application.
	//
	// Parameters:
	//  PermissionsQueries - Array - list of queries returned by the function.
	//                      RequestOnExternalResourcesUse of WorkInSafeMode module.
	//
	// Syntax:
	// Procedure WhenCompletingPermissionsForAccessToExternalResources (PermissionRequests) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources");
	
	// Appears when the request to use external resources is created.
	//
	// Parameters:
	//  Owner - AnyRef - the owner of the permissions requested
	//  for the use of the external resources, ReplacementMode - Boolean - the flag for a replacement of
	//  the permissions previously granted by owners, AddedPermissions - Array(XDTOObject) - array of
	//  added permissions, DeletedPermissions - Array(XDTOObject) - array of
	//  deleted permissions, StandardProcessing - Boolean, flag for the standard processing of
	//    request creation for external resources use.
	//  Result - UUID - request identifier (if inside
	//    the handler the value of parameter StandardProcessing is set to False).
	//
	// Syntax:
	// Procedure WhenRequestingPermissionsToUseExternalResources (Val Owner, Val ReplacementMode, Val AddedPermissions = Undefined, Val DeletedPermissions = Undefined, StandardProcessing, Result) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\WhenPermissionsForExternalResourcesUseAreRequested");
	
	// Appears when creation of a security profile is requested.
	//
	// Parameters:
	//  ApplicationModule - AnyRef - ref to infobase object
	//    representing the software module for which
	//  permissions are requested, StandardProcessing - Boolean, flag of
	//  standard processing, Result - UUID - request identifier (if inside
	//    the handler the value of parameter StandardProcessing is set to False).
	//
	// Syntax:
	// Procedure WhenRequestingSecurityProfileCreation (Value SoftwareModule, StandartProcessing, Result) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\WhenSecurityProfileCreationIsRequested");
	
	// Appears when security profile deletion is requested.
	//
	// Parameters:
	//  ApplicationModule - AnyRef - ref to infobase object
	//    representing the software module for which
	//  permissions are requested, StandardProcessing - Boolean, flag of
	//  standard processing, Result - UUID - request identifier (if inside
	//    the handler the value of parameter StandardProcessing is set to False).
	//
	// Syntax:
	// Procedure WhenRequestingSecurityProfileDeletion (Value SoftwareModule, StandartProcessing, Result) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\WhenSecurityProfileDeletionIsRequested");
	
	// Appears when the external module is connected. IN the body of the
	// handler procedure you can change the safe mode in which the connection will be installed.
	//
	// Parameters:
	//  ExternalModule - AnyRef - ref to infobase object
	//    that represents
	//  the external connected module, SafeMode - DefinedType.SafeMode - safe mode in which
	//    the external module will be connected to the infobase. Can be changed inside this procedure.
	//
	// Syntax:
	// Procedure WhenConnectingExternalModule (Value ExternalModule, SafeMode) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\WhenConnectingExternalModule");
	
	// Appears when the managers of external modules are registered.
	// Only for use inside SSL.
	//
	// Parameters:
	//  Managers - Array(CommonModule).
	//
	// Syntax:
	// Procedure WhenExternalModulesManagersAreRegistered(Managers) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.BasicFunctionality\WhenRegisteringExternalModulesManagers");
	
	// CLIENT EVENTS.
	
	// Called on the request confirmation to use external resources.
	// 
	// Parameters:
	//  IDs - Array (UUID), request identifiers
	//  that shall be applied, FormOwner - ManagedForm, a form that should be blocked
	//  until the end of the permissions application, ClosingAlert - AlertDetails, which will be called when permissions are successfully got.
	//  StandardProcessing - Boolean, a flag showing that standard permissions processor is applied to use external resources (connection to a server agent through COM-connection or administration server with querying the cluster connection parameters from the current user). Can be set to the
	//    value False inside the event handler, in this case the standard processing of the session end will not be executed.
	//
	// Syntax:
	// Procedure WhenConfirmingRequestsForExternalResourcesUse (Value RequestsIdentifiers, FormOwner, NotificationAboutClosing, StandardProcessing) Export
	//
	ClientEvents.Add(
		"StandardSubsystems.BasicFunctionality\WhenRequestsForExternalResourcesUseAreConfirmed");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Use of security profile.
//

// Checks if it is required to use the interactive mode of permissions request.
//
// Return value: Boolean.
//
Function PermissionsRequestInteractiveModeIsUsed()
	
	If SecurityProfilesCanBeUsed() Then
		
		Return GetFunctionalOption("SecurityProfilesAreUsed") AND Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Get();
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// External modules
//

// Returns the array of catalog managers that act as containers of the external modules.
//
// Return value: Array (CatalogManager).
//
Function ExternalModulesManagers()
	
	Managers = New Array();
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\WhenRegisteringExternalModulesManagers");
	For Each Handler IN EventHandlers Do
		Handler.Module.WhenRegisteringExternalModulesManagers(Managers);
	EndDo;
	
	Return Managers;
	
EndFunction

#EndRegion
