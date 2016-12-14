#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ListOfFoundBanks") Then
		
		SmallBusinessClientServer.SetListFilterItem(List, "Ref", Parameters.ListOfFoundBanks, True,DataCompositionComparisonType.InList);
		Items.List.ChoiceFoldersAndItems = FoldersAndItemsUse.Items;
		Items.List.Representation = TableRepresentation.List;
		
	EndIf;
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshAfterAdd" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure // NotificationProcessing()

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	//--> 15.12.2016 Switch off while work with classifier is not ready
	Return;
	//<--
	Cancel = True;
	
	QuestionText = NStr("en='There is an option to select bank from the classifier.
		|Select?';ru='Есть возможность подобрать банк из классификатора.
		|Подобрать?'");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("IsFolder", Group);
	NotifyDescription = New NotifyDescription("DetermineBankPickNeedFromClassifier", ThisObject, AdditionalParameters);
	
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure PickFromClassifier(Command)
	
	FormParameters = New Structure("CloseOnChoice, Multiselect", True, True);
	OpenForm("Catalog.RFBankClassifier.ChoiceForm", FormParameters, ThisForm);

EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the prompt result about selecting the bank from classifier
//
//
Procedure DetermineBankPickNeedFromClassifier(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		FormParameters = New Structure("ChoiceMode, CloseOnChoice, Multiselect", True, True, True);
		OpenForm("Catalog.RFBankClassifier.ChoiceForm", FormParameters, ThisForm);
		
	Else
		
		If AdditionalParameters.IsFolder Then
			
			OpenForm("Catalog.Banks.FolderForm", New Structure("IsFolder",True), ThisObject);
			
		Else
			
			OpenForm("Catalog.Banks.ObjectForm");
			
		EndIf;
		
	EndIf;
	
EndProcedure // DetermineBankPickNeedFromClassifier()

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
