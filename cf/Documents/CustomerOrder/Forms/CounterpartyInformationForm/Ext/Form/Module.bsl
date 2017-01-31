
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
