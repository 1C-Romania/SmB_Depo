
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Template = Documents.CustomerOrder.GetTemplate("CounterpartyInformation");
	
	TemplateArea = Template.GetArea("Title");
	Result.Put(TemplateArea);
	
	For Each String IN Parameters.CounterpartyInformation Do
		
		TemplateArea = Template.GetArea("String");
		FillPropertyValues(TemplateArea.Parameters, String);
		Result.Put(TemplateArea);
		
	EndDo;
	
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
