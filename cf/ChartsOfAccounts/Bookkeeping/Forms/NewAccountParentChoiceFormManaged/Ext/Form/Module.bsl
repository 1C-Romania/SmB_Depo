
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Account") Then
		Account = Parameters.Account;
	EndIf;	
	If Account.Parent.IsEmpty() Then
		Items.ParentLevel.ChoiceList.Clear();
		
		Items.ParentLevel.ChoiceList.Add(0, NStr("en='Root account';pl='Konto górnego poziomu';ru='Счет вышестоящего уровня'"));
		Items.ParentLevel.ChoiceList.Add(2, NStr("en='Subaccount to account';pl='Subkonto do konta';ru='Субсчет для счета'") + " " + Account);
	Else
		Items.ParentLevel.ChoiceList.Clear();
		
		Items.ParentLevel.ChoiceList.Add(0, NStr("en='Root account';pl='Konto górnego poziomu';ru='Счет вышестоящего уровня'"));
		Items.ParentLevel.ChoiceList.Add(1, NStr("en='Another subaccount to account';pl='Kolejne subkonto do konta';ru='Другой субсчет для счета'") + " " + Account.Parent);
		Items.ParentLevel.ChoiceList.Add(2, NStr("en='Subaccount to account';pl='Subkonto do konta';ru='Субсчет для счета'") + " " + Account);
	EndIf;
	
	ParentLevel = 0;
	
EndProcedure

&AtClient
Procedure CommandOK(Command)
	Close(GetParetRef());
EndProcedure

&AtServer
Function GetParetRef()
	Result = PredefinedValue("ChartOfAccounts.Bookkeeping.EmptyRef");
	If ParentLevel = 0 Then
		Result = PredefinedValue("ChartOfAccounts.Bookkeeping.EmptyRef");
	ElsIf ParentLevel = 1 Then
		Result = Account.Parent;
	Else
		Result = Account;
	EndIf;
	Return Result;
EndFunction

