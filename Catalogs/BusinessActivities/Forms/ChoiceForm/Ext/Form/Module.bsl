////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("GLExpenseAccount") Then
		
		If ValueIsFilled(Parameters.GLExpenseAccount) Then
			
			If Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
			   AND Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.CostOfGoodsSold
			   AND Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.Incomings Then
				
				MessageText = NStr("en = 'Business Activity should not be filled for this type of account!'");
				SmallBusinessServer.ShowMessageAboutError(, MessageText, , , , Cancel);
				
			EndIf;
			
		Else
			
			MessageText = NStr("en = 'Account is not selected!'");
			SmallBusinessServer.ShowMessageAboutError(, MessageText, , , , Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure



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
