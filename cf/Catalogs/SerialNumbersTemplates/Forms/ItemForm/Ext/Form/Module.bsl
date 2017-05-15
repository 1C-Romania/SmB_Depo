
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If TrimAll(Object.Description)="" Then
	    Cancel = True;
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Template is not filled!';ru = 'Шаблон не заполнен!'");
		Message.Message();
	EndIf;	
	
EndProcedure