////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Subsystem "Address classifier".
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Checks the updates for address classifier
// on website for those entities that have already beed exported.
//
// Parameters:
//     ExecuteParameters - CommandExecuteParameters, Structure - parameters of the form opening.
//
Procedure GetCheckAddressObjectUpdateRequired(ExecuteParameters = Undefined) Export
	
	ParametersStructure = New Structure("Source");
	
	If ExecuteParameters <> Undefined Then
		FillPropertyValues(ParametersStructure, ExecuteParameters);
	EndIf;
	
	Owner = ParametersStructure.Source;
		
	If Not RequestAccessWhenUsing() Then
		// Permissions are already obtained for the entire configuration.
		OpenUpdateCheckForm(ExecuteParameters);
		Return;
	EndIf;
		
	// Security profile query is required.
	NotifyDescription = New NotifyDescription(
		"GetSecurityPermissionsForAddressObjectsUpdateAvailabilityCheck", 
		ThisObject, ExecuteParameters
	);
	
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(
		AddressClassifierServerCall.QueryUpdateSecurityPermissions(), 
		Owner, 
		NotifyDescription,
	);
	
EndProcedure

// Opens classifier import form.
//
// Parameters:
//     Parameters - CommandExecuteParameters, Structure - parameters of the form opening.
//
Procedure ImportAddressClassifier(Parameters = Undefined) Export
	
	WindowParameters = New Structure("Uniqueness, Window, URL, Source", False);
	If Parameters <> Undefined Then
		FillPropertyValues(WindowParameters, Parameters);
	EndIf;
	
	FormParameters = New Structure;
	If TypeOf(Parameters) = Type("Structure") Then
		For Each KeyValue In Parameters Do
			FormParameters.Insert(KeyValue.Key, KeyValue.Value);
		EndDo;
	EndIf;
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	If ClientWorkParameters.AddressClassifierOutdated AND Not FormParameters.Property("StateCodeForImport") Then
		FormName = "InformationRegister.AddressObjects.Form.UpdateOutdatedClassifier";
	Else
		FormName = "InformationRegister.AddressObjects.Form.AddressClassifierExport";
	EndIf;
	OpenForm(FormName, FormParameters, 
		WindowParameters.Source, 
		WindowParameters.Uniqueness, 
		WindowParameters.Window, 
		WindowParameters.URL);
	
EndProcedure

// Checks the updates for address classifier
// on website for those entities that have already beed exported.
//
// Parameters:
//     ExecuteParameters - CommandExecuteParameters, Structure - parameters of the form opening.
//
Procedure OpenUpdateCheckForm(ExecuteParameters)
	
	If ExecuteParameters = Undefined Then
		ExecuteParameters = New Structure("Uniqueness, Window, URL, Source", False);
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Mode", "CheckUpdate");
	
	OpenForm("InformationRegister.AddressObjects.Form.AddressClassifierExport", FormParameters, 
		ExecuteParameters.Source, 
		ExecuteParameters.Uniqueness, 
		ExecuteParameters.Window, 
		ExecuteParameters.URL
	);

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Calls the directory selection dialog.
// 
// Parameters:
//     Form - ManagedForm - calling object.
//     DataPath          - String             - full name of form attribute that contains current value of the directory.
//                                                 ForExample.
//                                                "WorkingDirectory" or "Object.ImageCatalog".
//     Title            - String             - Title for dialog.
//     StandardProcessing - Boolean             - for use in the "AtSelectionStart" handler. Will
//                                                 be filled with False value.
//     CompletionAlert - NotifyDescription - it is called after successful transfer of a new value into the attribute.
//
Procedure ChooseDirectory(Val Form, Val DataPath, Val Title = Undefined, StandardProcessing = False, CompletionAlert = Undefined) Export
	
	StandardProcessing = False;
	
	ContinuationAlert = New NotifyDescription("SelectDirectoryWorksWithFilesExpansionsControlEnd", ThisObject, New Structure);
	ContinuationAlert.AdditionalParameters.Insert("Form",       Form);
	ContinuationAlert.AdditionalParameters.Insert("DataPath", DataPath);
	ContinuationAlert.AdditionalParameters.Insert("Title",   Title);
	
	ContinuationAlert.AdditionalParameters.Insert("CompletionAlert",   CompletionAlert);
	
	CommonUseClient.ShowQuestionAboutFileOperationsExtensionSetting(ContinuationAlert, , False);
EndProcedure

// End of a directory modeless selection.
//
Procedure SelectDirectoryWorksWithFilesExpansionsControlEnd(Val Result, Val AdditionalParameters) Export
	
	If Result <> True Then
		// Expansion setup refusal.
		Return;
	EndIf;
	
	Form       = AdditionalParameters.Form;
	DataPath = AdditionalParameters.DataPath;
	Title   = AdditionalParameters.Title;
	
	Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
	If Title <> Undefined Then
		Dialog.Title = Title;
	EndIf;
	
	ValueOwner = Form;
	CurrentValue  = Form;
	AttributeName     = DataPath;
	
	PartsWays = StrReplace(DataPath, ".", Chars.LF);
	For Position = 1 To StrLineCount(PartsWays) Do
		AttributeName     = StrGetLine(PartsWays, Position);
		ValueOwner = CurrentValue;
		CurrentValue  = CurrentValue[AttributeName];
	EndDo;
	
	Dialog.Directory = CurrentValue;
	
	NotifyDescription = New NotifyDescription("SelectDirectoryEndFileSelectionDialogDisplaying", ThisObject, AdditionalParameters);
	Dialog.Show(NotifyDescription);
	
EndProcedure

// End of the modal receipt of confirmation of getting resourses for the classifier update check.
//
Procedure GetSecurityPermissionsForAddressObjectsUpdateAvailabilityCheck(Val ClosingResult, Val AdditionalParameters) Export

	If ClosingResult <> DialogReturnCode.OK Then
		// No permission
		Return;
	EndIf;
	
	OpenUpdateCheckForm(AdditionalParameters);
EndProcedure

Function RequestAccessWhenUsing()
	
	Return False;
	
EndFunction

Procedure SelectDirectoryEndFileSelectionDialogDisplaying(Directory, AdditionalParameters) Export
	
	If Directory <> Undefined Then
		
		AdditionalParameters.Form[AdditionalParameters.DataPath] = Directory[0];
		
		If AdditionalParameters.CompletionAlert <> Undefined Then
			ExecuteNotifyProcessing(AdditionalParameters.CompletionAlert, Directory[0]);
		EndIf;
		
	EndIf;
	
EndProcedure

// Check for the availability of all required files for import.
//
// Parameters:
//     CodesOfStates      - Array    - contains numeric values - Codes of states 
//                                      - the Russian Federation territorial entities (for futher import).
//     Directory           - String    - directory with the verified files.
//     ImportParameters - Structure - contain fields.
//         * ImportingSourceCode - String - Describes the set of analyzed files. Possible values:
//                                           "DIRECTORY" "WEBSITE" "ITS".
//         * ErrorField           - String - attribute name to associate error messages with.
//
// Returns: 
//     Structure - result description. Contains fields.
//         * StatesPostCodes    - Array -       contains numeric values of states-entities post codes
//                                      for which all files are available.
//         * HasAllFiles    - Boolean       - check box indicating that it is possible to import all states.
//         *Errors          - Structure    - see description CommonUseClientServer.AddErrorToUser.
//         * AttachmentsByStates - Map - correspondence of files to states. Key can be:
//                                          - a number (state post code), then the value - array of attachment
//                                          file names required for this state import
//                                          - character "*", then value - array of attachment file
//                                          names required for all states import.
//
Procedure AnalysisClassifierFilesAvailabilityInDirectory(CompletionDescription, CodesOfStates, Directory, ImportParameters) Export
	
	WorkingDirectory = CommonUseClientServer.AddFinalPathSeparator(Directory);
	ErrorField = ImportParameters.ErrorField;
	
	Result = New Structure;
	Result.Insert("CodesOfStates",    CodesOfStates);
	Result.Insert("HasAllFiles",    True);
	Result.Insert("Errors",          Undefined);
	Result.Insert("FilesByStates", New Map);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("MissingFiles", New Map);
	AdditionalParameters.Insert("CompletionDescription", CompletionDescription);
	AdditionalParameters.Insert("Result", Result);
	AdditionalParameters.Insert("WorkingDirectory", WorkingDirectory);
	AdditionalParameters.Insert("ErrorField", ErrorField);
	NotifyDescription = New NotifyDescription("AnalysisFilesAvailabilityInDirectoryClassifierEnd", ThisObject, AdditionalParameters);
	
	ExecuteNotifyProcessing(NotifyDescription, 0);
	
EndProcedure

Procedure AnalysisFilesAvailabilityInDirectoryClassifierEnd(StatePostCode, AdditionalParameters) Export
	
	If StatePostCode <= AdditionalParameters.Result.CodesOfStates.UBound() Then
		
		StateCode = AdditionalParameters.Result.CodesOfStates[StatePostCode];
		// Set of files for each state.
		AdditionalParameters.Result.FilesByStates[StateCode] = New Array;
		
		FileName = Format(StateCode, "ND=2; NZ=; NLZ=; NG=") + ".ZIP";
		AdditionalParameters.Insert("StateCode", StateCode);
		AdditionalParameters.Insert("FileName", FileName);
		AdditionalParameters.Insert("StatePostCode", StatePostCode);
		NotifyDescription = New NotifyDescription("ClassifierInDirectoryAfterFilesSearchFilesAvailabilityAnalysis", ThisObject, AdditionalParameters);
		BeginFindingFiles(NotifyDescription, AdditionalParameters.WorkingDirectory, FileMask(FileName));
		
	Else // end of the cycle
		
		// Collect all in one call
		Presentation = AddressClassifierServerCall.StatePresentationByCode(AdditionalParameters.MissingFiles);
		
		For Each KeyValue In Presentation Do
			ErrorInfo = NStr("en='For state ""%1"" data file ""%2"" is not found';ru='Для региона ""%1"" не найден файл данных ""%2""'") + Chars.LF;
			ErrorInfo = ErrorInfo + NStr("en='Up to date address information can be exported on #EMPTY LINK#';ru='Актуальные адресные сведения можно загрузить по адресу http://its.1c.ru/download/fias'");
			
			CommonUseClientServer.AddUserError(AdditionalParameters.Result.Errors, AdditionalParameters.ErrorField,
				StringFunctionsClientServer.SubstituteParametersInString(ErrorInfo,
				KeyValue.Value, AdditionalParameters.MissingFiles[KeyValue.Key]), Undefined);
		EndDo;
		
		ExecuteNotifyProcessing(AdditionalParameters.CompletionDescription, AdditionalParameters.Result);
		
	EndIf;
	
EndProcedure

Procedure ClassifierInDirectoryAfterFilesSearchFilesAvailabilityAnalysis(FoundFiles, AdditionalParameters) Export
	
	FileStructure = New Structure("Exist, Name, BaseName, FullName, Path, Extension", False);
	If FoundFiles.Count() > 0 Then
		
		FileStructure.Exist = True;
		FillPropertyValues(FileStructure, FoundFiles[0]);
	EndIf;
	
	If FileStructure.Exist Then
		AdditionalParameters.Result.FilesByStates[AdditionalParameters.StateCode].Add(FileStructure.FullName);
	Else
		AdditionalParameters.Result.HasAllFiles = False;
		AdditionalParameters.MissingFiles.Insert(AdditionalParameters.StateCode, AdditionalParameters.FileName);
	EndIf;
	
	AnalysisFilesAvailabilityInDirectoryClassifierEnd(AdditionalParameters.StatePostCode + 1, AdditionalParameters);
	
EndProcedure

Function FileMask(FileName)
	
	SystemInfo = New SystemInfo;
	Platform = SystemInfo.PlatformType;
	
	IgnoreRegister = Platform = PlatformType.Windows_x86 Or Platform = PlatformType.Windows_x86_64;
	
	If IgnoreRegister Then
		Mask = Upper(FileName);
	Else
		Mask = "";
		For Position = 1 To StrLen(FileName) Do
			Char = Mid(FileName, Position, 1);
			TopRegister = Upper(Char);
			LowerRegister  = Lower(Char);
			If TopRegister = LowerRegister Then
				Mask = Mask + Char;
			Else
				Mask = Mask + "[" + TopRegister + LowerRegister + "]";
			EndIf;
		EndDo;
	EndIf;
	
	Return Mask;
	
EndFunction

#EndRegion