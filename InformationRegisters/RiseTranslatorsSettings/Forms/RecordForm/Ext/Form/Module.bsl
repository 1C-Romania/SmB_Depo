
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	For each language in Metadata.Languages Do
		Items.SettingValue.ChoiceList.Add(language.LanguageCode);
	EndDo;
	
	For each user in InfoBaseUsers.GetUsers() Do
		Users.Add(user.Name);
	EndDo;
EndProcedure

&AtClient
Procedure UserNameStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	Users.ShowChooseItem(New NotifyDescription("UserNameEndChoice", ThisForm));
EndProcedure

&AtClient
Procedure UserNameEndChoice(Result, Params) Export
	If Result <> Undefined Then
		Record.UserName = Result.Value;
	EndIf; 
EndProcedure