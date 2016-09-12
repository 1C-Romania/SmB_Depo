﻿
&AtServer
Procedure FillFormByObject()
	
	WorkWithBanksOverridable.ReadManualEditFlag(ThisForm);
	
	Items.PagesActivityDiscontinued.CurrentPage = ?(ActivityDiscontinued,
		Items.PageLabelActivityDiscontinued, Items.PageBlank);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// Notify the bank account form about the change of bank requisites
	Notify("RecordedItemBank", Object.Ref, ThisForm);

EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		If Parameters.Code <> "" Then
			Object.Code = Parameters.Code;
		EndIf;
		
		If Parameters.CorrAccount <> "" Then
			Object.CorrAccount = Parameters.CorrAccount;
		EndIf;
		
		FillFormByObject();
	EndIf;
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillFormByObject();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.ManualChanging = ?(ManualChanging = Undefined, 2, ManualChanging);
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	Text = NStr("en='Supplied data is updated automatically."
"After the manual change this item will not be updated automatically."
"Continue with change?';ru='Поставляемые данные обновляются автоматически."
"После ручного изменения автоматическое обновление этого элемента производиться не будет."
"Продолжить с изменением?'");
	Result = Undefined;

	ShowQueryBox(New NotifyDescription("ChangeEnd", ThisObject), Text, QuestionDialogMode.YesNo,, DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure ChangeEnd(Result1, AdditionalParameters) Export
    
    Result = Result1;
    
    If Result = DialogReturnCode.Yes Then
        
        LockFormDataForEdit();
        Modified = True;
        ManualChanging    = True;
        
        WorkWithBanksClientOverridable.ProcessManualEditFlag(ThisForm);
        
    EndIf;

EndProcedure

&AtClient
Procedure UpdateFromClassifier(Command)
	
	ExecuteUpdate = False;
	WorkWithBanksClientOverridable.RefreshItemFromClassifier(ThisForm, ExecuteUpdate);
	
EndProcedure

&AtServer
Procedure UpdateAtServer()
	
	WorkWithBanksOverridable.RestoreItemFromSharedData(ThisForm);
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of response on the question about data update from classifier
//
Procedure DetermineNecessityForDataUpdateFromClassifier(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		LockFormDataForEdit();
		Modified = True;
		UpdateAtServer();
		NotifyChanged(Object.Ref);
		
	EndIf;
	
EndProcedure // DetermineDataUpdateNeedFromClassifier()

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

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
