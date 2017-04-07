
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Template = ExchangePlans.ExchangeSmallBusinessAccounting20.GetTemplate("DetailedInformationAboutExchange");
	
	HTMLDocumentField = Template.GetText();
	
	Title = NStr("en='Information about data synchronization with ""1C: Accounting 8, ed. 2.0""';ru='Информация о синхронизации данных с ""1C: Бухгалтерия предприятия 8, ред. 2.0""'");
	
EndProcedure
