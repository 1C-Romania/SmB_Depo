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
