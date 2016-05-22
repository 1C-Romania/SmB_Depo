
&AtServer
Procedure FillFormByObject()
	
	WorkWithBanksOverridable.ReadManualEditFlag(ThisForm);
	
EndProcedure



///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		
		FillFormByObject();
		
	EndIf;
	
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
	
	Text = NStr("en = 'Supplied data is updated automatically.
		|After the manual change this item will not be updated automatically.
		|Continue with change?'");
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

