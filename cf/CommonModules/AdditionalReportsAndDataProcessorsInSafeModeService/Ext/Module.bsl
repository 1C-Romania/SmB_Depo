////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and processing", expansion
// of safe mode, service procedures and functions.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Add handlers of the service events (subsriptions).

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
		"AdditionalReportsAndDataProcessorsInSafeModeService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenRegisteringExternalModulesManagers"].Add(
		"AdditionalReportsAndDataProcessorsInSafeModeService");
	
EndProcedure

// Appears when the managers of external modules are registered.
//
// Parameters:
//  Managers - Array(CommonModule).
//
Procedure WhenRegisteringExternalModulesManagers(Managers) Export
	
	Managers.Add(AdditionalReportsAndDataProcessorsInSafeModeService);
	
EndProcedure

// Returns template of security proattachment file name for the external module.
// Function should return the same value multiple times.
//
// Parameters:
//  ExternalModule - AnyRef, reference to the external module,
//
// Returns - String - pattern of the security
//  proattachment file name containing %1 characters instead of which a unique identifier will be substituted later.
//
Function SecurityProfileTemplateName(Val ExternalModule) Export
	
	Kind = CommonUse.ObjectAttributeValue(ExternalModule, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		Return "AdditionalReport_%1"; // Not localized
		
	Else
		
		Return "AdditionalDataProcessor_%1"; // Not localized
		
	EndIf;
	
EndFunction

// Returns the icon that displays external module.
//
//  ExternalModule - AnyRef, reference to the external module,
//
// Returns - Picture.
//
Function ExternalModuleIcon(Val ExternalModule) Export
	
	Kind = CommonUse.ObjectAttributeValue(ExternalModule, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		Return PictureLib.Report;
		
	Else
		
		Return PictureLib.DataProcessor;
		
	EndIf;
	
EndFunction

// Returns the dictionary of presentations for external container modules.
//
// Returns - Structure:
//  * Nominative - String, presentation of external module type
//  in nominative case, * Genitive - String, presentation of external module type in genitive case.
//
Function ExternalModuleContainerDictionary() Export
	
	Result = New Structure();
	
	Result.Insert("Nominative", NStr("en='Additional report of data processor';ru='Дополнительного отчета или обработки'"));
	Result.Insert("Genitive", NStr("en='Additional report of data processor';ru='Дополнительного отчета или обработки'"));
	
	Return Result;
	
EndFunction

// Returns the array of reference metadata objects
//  which can be used as an external modules container.
//
// Returns - Array(MetadataObject).
//
Function ExternalModulesContainers() Export
	
	Result = New Array();
	Result.Add(Metadata.Catalogs.AdditionalReportsAndDataProcessors);
	Return Result;
	
EndFunction

// Fills out a list of queries for external permissions
// that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	NewQueries = QueriesOnPermissionsForAdditionalDataProcessors();
	CommonUseClientServer.SupplementArray(PermissionsQueries, NewQueries);
	
EndProcedure

Function QueriesOnPermissionsForAdditionalDataProcessors(Val ValueFO = Undefined) Export
	
	If ValueFO = Undefined Then
		ValueFO = GetFunctionalOption("UseAdditionalReportsAndDataProcessors");
	EndIf;
	
	Result = New Array();
	
	QueryText =
		"SELECT DISTINCT
		|	AdditionalReportsAndDataProcessorsPermissions.Ref AS Ref
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.permissions AS AdditionalReportsAndDataProcessorsPermissions
		|WHERE
		|	AdditionalReportsAndDataProcessorsPermissions.Ref.Publication <> &Publication";
	Query = New Query(QueryText);
	Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Object = Selection.Ref.GetObject();
		NewQueries = QueriesOnPermissionsForAdditionalDataProcessor(Object, Object.permissions.Unload(), ValueFO);
		CommonUseClientServer.SupplementArray(Result, NewQueries);
		
	EndDo;
	
	Return Result;
	
EndFunction

Function QueriesOnPermissionsForAdditionalDataProcessor(Val Object, Val PermissionsInData, Val ValueFO = Undefined, Val DeletionMark = Undefined) Export
	
	RequestedPermissions = New Array();
	
	If ValueFO = Undefined Then
		ValueFO = GetFunctionalOption("UseAdditionalReportsAndDataProcessors");
	EndIf;
	
	If DeletionMark = Undefined Then
		DeletionMark = Object.DeletionMark;
	EndIf;
	
	ClearPermissions = False;
	
	If Not ValueFO Then
		ClearPermissions = True;
	EndIf;
	
	If Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled Then
		ClearPermissions = True;
	EndIf;
	
	If DeletionMark Then
		ClearPermissions = True;
	EndIf;
	
	If Not ClearPermissions Then
		
		ThereWerePermissions = WorkInSafeModeService.ExternalModuleConnectionMode(Object.Ref) <> Undefined;
		ThereArePermissions = Object.permissions.Count() > 0;
		
		If ThereWerePermissions Or ThereArePermissions Then
			
			If Object.PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_2_2 Then
				
				RequestedPermissions = New Array();
				For Each PermissionInData IN PermissionsInData Do
					Resolution = XDTOFactory.Create(XDTOFactory.Type(WorkInSafeModeService.Package(), PermissionInData.TypePermissions));
					PropertiesInData = PermissionInData.Parameters.Get();
					FillPropertyValues(Resolution, PropertiesInData);
					RequestedPermissions.Add(Resolution);
				EndDo;
				
			Else
				
				OldPermissions = New Array();
				For Each PermissionInData IN PermissionsInData Do
					Resolution = XDTOFactory.Create(XDTOFactory.Type("http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/1.0.0.1", PermissionInData.TypePermissions));
					PropertiesInData = PermissionInData.Parameters.Get();
					FillPropertyValues(Resolution, PropertiesInData);
					OldPermissions.Add(Resolution);
				EndDo;
				
				RequestedPermissions = AdditionalReportsAndDataProcessorsInSafeModeInterface.ConvertVersionPermissions_2_1_3_InVersionPermissions_2_2_2(Object, OldPermissions);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return WorkInSafeModeService.PermissionsRequestForExternalModule(Object.Ref, RequestedPermissions);
	
EndFunction

// Only for internal use.
Function GenerateSessionKeyExpansionOfSafeMode(Val DataProcessor) Export
	
	Return DataProcessor.UUID();
	
EndFunction

// Only for internal use.
Function GetPermissionsExtensionSafeModeSession(Val SessionKey) Export
	
	SetPrivilegedMode(True);
	
	StandardProcessing = True;
	PermissionDescriptions = Undefined;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AdditionalReportsAndDataProcessors\OnGetSafeModeSessionsPermissions");
	
	For Each Handler IN EventHandlers Do
		
		Handler.Module.OnGetSafeModeSessionsPermissions(SessionKey, PermissionDescriptions, StandardProcessing);
		
	EndDo;
	
	If StandardProcessing Then
		
		Ref = Catalogs.AdditionalReportsAndDataProcessors.GetRef(SessionKey);
		QueryText =
			"SELECT
			|	permissions.TypePermissions AS TypePermissions,
			|	permissions.Parameters AS Parameters
			|FROM
			|	Catalog.AdditionalReportsAndDataProcessors.permissions AS permissions
			|WHERE
			|	permissions.Ref = &Ref";
		Query = New Query(QueryText);
		Query.SetParameter("Ref", Ref);
		PermissionDescriptions = Query.Execute().Unload();
		
	EndIf;
	
	Result = New Map();
	
	For Each DetailsPermissions IN PermissionDescriptions Do
		
		DefinitionType = XDTOFactory.Type(
			AdditionalReportsAndDataProcessorsInSafeModeInterface.Package(),
			DetailsPermissions.TypePermissions);
		
		Result.Insert(DefinitionType, DetailsPermissions.Parameters.Get());
		
	EndDo;
	
	Return Result;
	
EndFunction

// Only for internal use.
Function ExecuteScriptSafeMode(Val SessionKey, Val Script, Val ExecutableObject, ExecuteParameters, SavedParameters = Undefined, DestinationObjects = Undefined) Export
	
	Exceptions = AdditionalReportsAndDataProcessorsInSafeModeReUse.GetAllowedMethods();
	TemporaryFilesForDeletion = New Array;
	
	If SavedParameters = Undefined Then
		SavedParameters = New Structure();
	EndIf;
	
	For Each ScriptStep IN Script Do
		
		PerformSafely = True;
		ExecutableFragment = "";
		
		If ScriptStep.ActionKind = AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeActionsCallMethodDataProcessors() Then
			
			ExecutableFragment = "ExecutableObject." + ScriptStep.MethodName;
			
		ElsIf ScriptStep.ActionKind = AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeActionsCallConfigurationMethod() Then
			
			ExecutableFragment = ScriptStep.MethodName;
			
			If Exceptions.Find(ScriptStep.MethodName) <> Undefined Then
				PerformSafely = False;
			EndIf;
			
		Else
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Unknown action kind for script stage: %1';ru='Неизвестный вид действия для этапа сценария: %1'"),
				ScriptStep.ActionKind);
			
		EndIf;
		
		UnsavedParameters = New Array();
		
		SubstringOptions = "";
		
		MethodParameters = ScriptStep.Parameters;
		For Each MethodParameter IN MethodParameters Do
			
			If Not IsBlankString(SubstringOptions) Then
				SubstringOptions = SubstringOptions + ", ";
			EndIf;
			
			If MethodParameter.Type = AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeOfValueParameter() Then
				
				UnsavedParameters.Add(MethodParameter.Value);
				SubstringOptions = SubstringOptions + "UnsavedParameters.Get(" +
					UnsavedParameters.UBound() + ")";
				
			ElsIf MethodParameter.Type = AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeOfKeyParameterSession() Then
				
				SubstringOptions = SubstringOptions + "SessionKey";
				
			ElsIf MethodParameter.Type = AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeParameterValuesAreSavedCollection() Then
				
				SubstringOptions = SubstringOptions + "SavedParameters";
				
			ElsIf MethodParameter.Type = AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeOfParameterValueToBeStored() Then
				
				SubstringOptions = SubstringOptions + "SavedParameters." + MethodParameter.Value;
				
			ElsIf MethodParameter.Type = AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeParameterObjectsAssigned() Then
				
				SubstringOptions = SubstringOptions + "DestinationObjects";
				
			ElsIf MethodParameter.Type = AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeParameterCommandsPerformParameter() Then
				
				SubstringOptions = SubstringOptions + "ExecuteParameters." + MethodParameter.Value;
				
			Else
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Unknown parameter for script stage: %1';ru='Неизвестный параметр для этапа сценария: %1'"),
					MethodParameter.Type);
				
			EndIf;
			
		EndDo;
		
		ExecutableFragment = ExecutableFragment + "(" + SubstringOptions + ")";
		
		If PerformSafely <> SafeMode() Then
			SetSafeMode(PerformSafely);
		EndIf;
		
		If Not IsBlankString(ScriptStep.SaveResult) Then
			Result = Eval(ExecutableFragment);
			SavedParameters.Insert(ScriptStep.SaveResult, Result);
		Else
			Execute(ExecutableFragment);
		EndIf;
		
	EndDo;
	
EndFunction

// Only for internal use.
Procedure CheckLegitimacyOfExecutionOperations(Val SessionKey, Val Resolution) Export
	
	TypeRequiredPermissions = Resolution.Type();
	
	SessionPermissions = GetPermissionsExtensionSafeModeSession(SessionKey);
	PermissionRestrictions = SessionPermissions.Get(TypeRequiredPermissions);
	
	If PermissionRestrictions = Undefined Then
		
		Raise PermissionIsNotGrantedTextOfException(
			SessionKey, TypeRequiredPermissions);
		
	Else
		
		CheckedRestrictions = TypeRequiredPermissions.Properties;
		For Each CheckedRestriction IN CheckedRestrictions Do
			
			ValueRestrictions = Undefined;
			If PermissionRestrictions.Property(CheckedRestriction.LocalName, ValueRestrictions) Then
				
				If ValueIsFilled(ValueRestrictions) Then
					
					Limiter = Resolution.GetXDTO(CheckedRestriction);
					
					If ValueRestrictions <> Limiter.Value Then
						
						Raise PermissionIsNotGrantedTextOfExceptionForLimiter(
							SessionKey, TypeRequiredPermissions, CheckedRestriction, Limiter.Value);
						
					EndIf;
					
				EndIf;
				
			Else
				
				If Not CheckedRestriction.Nillable Then
					
					Raise ExceptionTextNotInstalledLimiterIsRequired(
						SessionKey, TypeRequiredPermissions, CheckedRestriction);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// For an internal use.
Function GetFileFromTemporaryStore(Val BinaryDataAddress) Export
	
	TempFile = GetTempFileName();
	BinaryData = GetFromTempStorage(BinaryDataAddress);
	BinaryData.Write(TempFile);
	Return TempFile;
	
EndFunction

// Only for internal use.
Function CheckCorrectnessOfCallOnEnvironment() Export
	
	Return SafeMode() = False;
	
EndFunction

// Only for internal use.
Function GeneratePermissionPresentation(Val permissions) Export
	
	PermissionDescriptions = AdditionalReportsAndDataProcessorsInSafeModeReUse.Dictionary();
	
	Result = "<HTML><BODY bgColor=#fcfaeb>";
	
	For Each Resolution IN permissions Do
		
		TypePermissions = Resolution.TypePermissions;
		
		DetailsPermissions = PermissionDescriptions.Get(
			XDTOFactory.Type(
				AdditionalReportsAndDataProcessorsInSafeModeInterface.Package(),
				TypePermissions));
		
		PresentationPermissions = DetailsPermissions.Presentation;
		
		PresentationParameters = "";
		Parameters = Resolution.Parameters.Get();
		
		If Parameters <> Undefined Then
			
			For Each Parameter IN Parameters Do
				
				If Not IsBlankString(PresentationParameters) Then
					PresentationParameters = PresentationParameters + ", ";
				EndIf;
				
				PresentationParameters = PresentationParameters + String(Parameter.Value);
				
			EndDo;
			
		EndIf;
		
		If Not IsBlankString(PresentationParameters) Then
			PresentationPermissions = PresentationPermissions + " (" + PresentationParameters + ")";
		EndIf;
		
		Result = Result + StringFunctionsClientServer.SubstituteParametersInString(
			"<LI><FONT size=2>%1 <A href=""%2"">%3</A></FONT>",
			PresentationPermissions,
			"internal:" + TypePermissions,
			NStr("en='More...';ru='Подробнее...'"));
		
	EndDo;
	
	Result = Result + "</LI></BODY></HTML>";
	
	Return Result;
	
EndFunction

// Only for internal use.
Function GenerateDetailedPermissionsDescription(Val TypePermissions, Val PermissionParameters) Export
	
	PermissionDescriptions = AdditionalReportsAndDataProcessorsInSafeModeReUse.Dictionary();
	
	Result = "<HTML><BODY bgColor=#fcfaeb>";
	
	DetailsPermissions = PermissionDescriptions.Get(
		XDTOFactory.Type(
			AdditionalReportsAndDataProcessorsInSafeModeInterface.Package(),
			TypePermissions));
	
	PresentationPermissions = DetailsPermissions.Presentation;
	DetailsPermissions = DetailsPermissions.Definition;
	
	ParameterDescriptions = Undefined;
	HasParameters = DetailsPermissions.Property("Parameters", ParameterDescriptions);
	
	Result = Result + "<P><FONT size=2><A href=""internal:home"">&lt;&lt; Back k list permissions</A></FONT></P>";
	
	Result = Result + StringFunctionsClientServer.SubstituteParametersInString(
		"<P><STRONG><FONT size=4>%1</FONT></STRONG></P>",
		PresentationPermissions);
	
	Result = Result + StringFunctionsClientServer.SubstituteParametersInString(
		"<P><FONT size=2>%1%2</FONT></P>", DetailsPermissions, ?(
			HasParameters,
			NStr("en=' with following restrictions:';ru=' со следующими ограничениями:'"),
			"."));
	
	If HasParameters Then
		
		Result = Result + "<UL>";
		
		For Each Parameter IN ParameterDescriptions Do
			
			ParameterName = Parameter.Name;
			ParameterValue = PermissionParameters[ParameterName];
			
			If ValueIsFilled(ParameterValue) Then
				
				ParameterDescription = StringFunctionsClientServer.SubstituteParametersInString(
					Parameter.Definition, ParameterValue);
				
			Else
				
				ParameterDescription = StringFunctionsClientServer.SubstituteParametersInString(
					"<B>%1</B>", Parameter.DescriptionOfAnyValue);
				
			EndIf;
			
			Result = Result + StringFunctionsClientServer.SubstituteParametersInString(
				"<LI><FONT size=2>%1</FONT>", ParameterDescription);
			
		EndDo;
		
		Result = Result + "</LI></UL>";
		
	EndIf;
	
	DetailsOfConsequences = "";
	If DetailsPermissions.Property("Effects", DetailsOfConsequences) Then
		
		Result = Result + StringFunctionsClientServer.SubstituteParametersInString(
			"<P><FONT size=2><EM>%1</EM></FONT></P>",
			DetailsOfConsequences);
		
	EndIf;
	
	Result = Result + "<P><FONT size=2><A href=""internal:home"">&lt;&lt; Back k list permissions</A></FONT></P>";
	
	Result = Result + "</BODY></HTML>";
	
	Return Result;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Only for internal use.
Function PermissionIsNotGrantedTextOfException(Val SessionKey, Val TypeRequiredPermissions)
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Permission (%2)%3 is not provided for additional report or data processor %1.';ru='Дополнительному отчету или обработке %1 не предоставлено разрешение {%2}%3!'"),
			String(SessionKey), TypeRequiredPermissions.NamespaceURI, TypeRequiredPermissions.Name);
	
EndFunction

// Only for internal use.
Function PermissionIsNotGrantedTextOfExceptionForLimiter(Val SessionKey, Val TypeRequiredPermissions, Val CheckedRestriction, Val Limiter)
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='For additional report or data
		|processor %1 the {%2}%3 permission
		|is not granted when delimiter %4 is %5.';ru='Для дополнительного отчета
		|или обработки %1 не предоставлено
		|разрешение {%2}%3 при значении ограничителя %4 равном %5!'"),
		String(SessionKey), TypeRequiredPermissions.NamespaceURI, TypeRequiredPermissions.Name,
		CheckedRestriction.LocalName, Limiter);
	
EndFunction

// Only for internal use.
Function ExceptionTextNotInstalledLimiterIsRequired(Val SessionKey, Val TypeRequiredPermissions, Val CheckedRestriction)
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='When the {%2}%3 permission was
		|granted for additional report or data processor %1, mandatory delimiter %4 was not specified.';ru='Для дополнительного отчета
		|или обработки %1 при предоставлении разрешения {%2}%3 не был указан обязательный ограничитель %4!'"),
		String(SessionKey), TypeRequiredPermissions.NamespaceURI, TypeRequiredPermissions.Name,
		CheckedRestriction.LocalName);
	
EndFunction

#EndRegion
