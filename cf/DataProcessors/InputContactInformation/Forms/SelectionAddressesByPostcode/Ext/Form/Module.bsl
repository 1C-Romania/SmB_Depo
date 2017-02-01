// Form parameters:
//     IndexOf                            - Number  - Postal code to search address variants.
//     HideObsoleteAddresses        - Boolean - check box indicating that obsolete addresses are hidden.
//     AddressFormat - String - version of the classifier.
//
// Selection result:
//     Structure - with
//         * Cancel fields                      - Boolean - check box indicating that an error occurred while processing.
//         * BriefErrorPresentation - String - Error description.
//         * Identifier              - UUID - Address data.
//         * Presentation              - String                  - Address data.
//         * Code                     - Number                   - Address data.
//
// ---------------------------------------------------------------------------------------------------------------------
//
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SearchParameters = New Structure;
	SearchParameters.Insert("HideObsolete", Parameters.HideObsoleteAddresses);
	
	If Parameters.Property("AddressFormat") Then
		SearchParameters.Insert("AddressFormat", Parameters.AddressFormat);
	Else
		SearchParameters.Insert("AddressFormat", "FIAS");
	EndIf;
	
	Parameters.Property("IndexOf", IndexOf);
	ClassifierData = ContactInformationManagementService.ClassifierAddressesByPostcode(IndexOf, SearchParameters);
	
	If ClassifierData.Cancel Then
		// Service at maintenance
		BriefErrorDescription = ClassifierData.BriefErrorDescription;
		Return;
		
	ElsIf ClassifierData.Data.Count() = 0 Then
		// No data, selection functions are not applicable.
		BriefErrorDescription = NStr("en='Code is not found in the address classifier.';ru='Индекс не найден в адресном классификаторе.'");
		Return;
	EndIf;
	
	AddressVariants.Load(ClassifierData.Data);
	CommonPartPresentation = ClassifierData.CommonPartPresentation;
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
Procedure AddressVariantsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	MakeSelection(SelectedRow);
	
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
	
	WarningIrrelevant = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Address ""%2, %1"" is not applicable.
		|Continue?';ru='Адрес ""%2, %1"" неактуален.
		|Продолжить?'"),
		TrimAll(CommonPartPresentation), Data.Presentation
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
	
	Result = New Structure("IndexOf, Identifier, Presentation", IndexOf);
	Result.Insert("BriefErrorDescription", BriefErrorDescription);
	Result.Insert("Cancel",                      Cancel);
	
	If Data <> Undefined Then
		FillPropertyValues(Result, Data);
	EndIf;
	
	NotifyChoice(Result);
EndProcedure

#EndRegion
