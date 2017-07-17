
#Region ProgrammInterface


Function CanCopyRows(TP, TPCurrentData) Export
	
	If TPCurrentData <> Undefined AND TP.Count() <> 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Procedure NotifyUserCopyRows(CopiedCount) Export
	
	TitleText = NStr("en='Lines are copied';ru='Строки скопированы'"); // Rows are copied
	MessageText = NStr("en='Lines are copied to the clipboard (%CopiedCount%)';ru='В буфер обмена скопированы строки (%CopiedCount%)'");  //Rows are copied to clipboard
	MessageText = StrReplace(MessageText, "%CopiedCount%", CopiedCount);
	
	ShowUserNotification(TitleText,, MessageText);
	
	Notify("TabularPartCopyRowsClipboard");
	
EndProcedure

Procedure NotifyUserPasteRows(CopiedCount, PastedCount) Export
	
	TitleText = NStr("en='Lines are inserted';ru='Строки вставлены'");
	MessageText = NStr("en='Rows are inserted from the clipboard (%PastedCount% of %CopiedCount%)';ru='Из буфера обмена вставлены строки (%PastedCount% из %CopiedCount%)'");
	MessageText = StrReplace(MessageText, "%PastedCount%", PastedCount);
	MessageText = StrReplace(MessageText, "%CopiedCount%", CopiedCount);
	
	ShowUserNotification(TitleText,, MessageText);
	
EndProcedure


Procedure NotificationProcessing(Items, TPName) Export
	
	SetButtonsVisibility(Items, TPName, True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure SetButtonsVisibility(FormItems, TPName, IsCopiedRows)
	
	FormItems[TPName + "CopyRows"].Enabled = True;
	
	If IsCopiedRows Then
		FormItems[TPName + "PasteRows"].Enabled = True;
	Else
		FormItems[TPName + "PasteRows"].Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion
