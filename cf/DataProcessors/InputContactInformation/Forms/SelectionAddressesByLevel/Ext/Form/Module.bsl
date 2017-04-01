// Form parameters:
//     Level                           - Number - Requested level.
//     Parent                          - UUID - Parent object.
//     HideObsoleteAddresses        - Boolean - check box indicating that obsolete addresses are hidden.
//     AddressFormat - String - version of the classifier.
//     ID                     - UUID - Current address item.
//     Presentation                     - String - Current item presentation. it is used
//                                                  if the Identifier is not specified.
//
// Selection result:
//     Structure - with
//         * Cancel fields                      - Boolean - check box indicating that an error occurred while processing.
//         * BriefErrorPresentation - String - Error description.
//         * Identifier              - UUID - Address data.
//         * Presentation              - String                  - Address data.
//         * StateIsImported             - Boolean                  - Only for states, True if there
//                                                                  are records.
// ---------------------------------------------------------------------------------------------------------------------
//
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("Parent", Parent);
	Parameters.Property("Level",  Level);
	
	Parameters.Property("AddressFormat", AddressFormat);
	Parameters.Property("HideObsolete", HideObsolete);
	
	If IsBlankString("AddressFormat") Then
		AddressFormat = "FIAS";
	EndIf;
	
	SearchParameters = New Structure;
	SearchParameters.Property("AddressFormat", AddressFormat);
	SearchParameters.Property("HideObsolete", HideObsolete);
	
	ClassifierData = ContactInformationManagementService.AddressesForInteractiveSelection(Parent, Level, SearchParameters);
	
	If ClassifierData.Cancel Then
		// Service at maintenance
		BriefErrorDescription = NStr("en='AutoComplete and Address Checking are not available:';ru='Автоподбор и проверка адреса недоступны:'") + Chars.LF + ClassifierData.BriefErrorDescription;
		Return;
		
	ElsIf ClassifierData.Data.Count() = 0 Then
		BriefErrorDescription = NStr("en='Field ""';ru='Поле ""'") + Parameters.Presentation + NStr("en='"" does not contain address information for selection.';ru='"" не содержит адресных сведений для выбора.'");;
		// No data, selection functions are not applicable.
		
	EndIf;
	
	AddressVariants.Load(ClassifierData.Data);
	Title = ClassifierData.Title;
	
	// Current row
	CurrentValue = Undefined;
	Candidates       = Undefined;
	
	Parameters.Property("ID", CurrentValue);
	If ValueIsFilled(CurrentValue) Then
		Candidates = AddressVariants.FindRows( New Structure("ID", CurrentValue) );
	Else
		Parameters.Property("Presentation", CurrentValue);
		If ValueIsFilled(CurrentValue) Then
			Candidates = AddressVariants.FindRows( New Structure("Presentation", CurrentValue) );
		EndIf;
	EndIf;
	
	If Candidates <> Undefined AND Candidates.Count() > 0 Then
		Items.AddressVariants.CurrentRow = Candidates[0].GetID();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not IsBlankString(BriefErrorDescription) Then
		NotifyOwner(Undefined, True);
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure AddressVariantsSelectionValue(Item, Value, StandardProcessing)
	
	MakeSelection(Value);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure MakeSelection(Val LineNumber)
	
	Data = AddressVariants.FindByID(LineNumber);
	If Data = Undefined Then
		Return;
		
	ElsIf Not Data.NotActual Then
		NotifyOwner(Data);
		Return;
		
	EndIf;
	
	Notification = New NotifyDescription("MakeSelectionEndQuestion", ThisObject, Data);
	
	WarningIrrelevant = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Address ""%1"" is not applicable.
		|Continue?';ru='Адрес ""%1"" неактуален.
		|Продолжить?'"),
		Data.Presentation
	);
		
	TitleWarnings = NStr("en='Confirmation';ru='Подтверждение'");
	
	ShowQueryBox(Notification, WarningIrrelevant, QuestionDialogMode.YesNo, , ,TitleWarnings);
		
EndProcedure

&AtClient
Procedure MakeSelectionEndQuestion(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		NotifyOwner(AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyOwner(Val Data, Cancel = False)
	
	Result = New Structure("StateImported, Identifier, Presentation");
	Result.Insert("BriefErrorDescription", BriefErrorDescription);
	Result.Insert("Cancel",                      Cancel);
	Result.Insert("Level",                    Level);
	
	If Data <> Undefined Then
		FillPropertyValues(Result, Data);
	EndIf;
	
	NotifyChoice(Result);
EndProcedure

#EndRegion
