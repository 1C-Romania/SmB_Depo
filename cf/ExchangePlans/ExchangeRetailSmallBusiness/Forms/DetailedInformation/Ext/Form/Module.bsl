﻿
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Template = ExchangePlans.ExchangeRetailSmallBusiness.GetTemplate("DetailedInformation");
	
	HTMLDocumentField = Template.GetText();
	
	Title = NStr("en='Information about data synchronization with 1C:Standard subsystem library';ru='Информация о синхронизации данных с 1С:Библиотека стандартных подсистем'");

EndProcedure














