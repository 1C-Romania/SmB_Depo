
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Template = ExchangePlans.ExchangeSmallBusinessAccounting30.GetTemplate("DetailedInformationAboutExchange");
	
	HTMLDocumentField = Template.GetText();
	
	Title = NStr("en='Information about data synchronization with ""1C: Accounting 8, ed. 3.0""';ru='Информация о синхронизации данных с ""1C: Бухгалтерия предприятия 8, ред. 3.0""'");
	
EndProcedure














