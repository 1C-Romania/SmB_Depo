#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// Procedure fills catalog by default
//
Procedure FillAvailableCustomerAcquisitionChannels() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	CustomerAcquisitionChannels.Ref AS Channel
		|FROM
		|	Catalog.CustomerAcquisitionChannels AS CustomerAcquisitionChannels";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	// 1. Website
	Channel = Catalogs.CustomerAcquisitionChannels.CreateItem();
	Channel.SetNewCode();
	Channel.Description = NStr("ru = 'Сайт'; en = 'Website'");
	
	InfobaseUpdate.WriteData(Channel);
	
	// 2. E-mail
	Channel = Catalogs.CustomerAcquisitionChannels.CreateItem();
	Channel.SetNewCode();
	Channel.Description = NStr("ru = 'E-mail'; en = 'E-mail'");
	
	InfobaseUpdate.WriteData(Channel);
	
	// 3. Звонок
	Channel = Catalogs.CustomerAcquisitionChannels.CreateItem();
	Channel.SetNewCode();
	Channel.Description = NStr("ru = 'Звонок'; en = 'Phone call'");
	
	InfobaseUpdate.WriteData(Channel);
	
	// 4. Выставка
	Channel = Catalogs.CustomerAcquisitionChannels.CreateItem();
	Channel.SetNewCode();
	Channel.Description = NStr("ru = 'Выставка'; en = 'Exhibition'");
	
	InfobaseUpdate.WriteData(Channel);
	
	// 5. Рекламная кампания
	Channel = Catalogs.CustomerAcquisitionChannels.CreateItem();
	Channel.SetNewCode();
	Channel.Description = NStr("ru = 'Рекламная кампания'; en='Advertising campaign'");
	
	InfobaseUpdate.WriteData(Channel);
	
EndProcedure

#EndRegion

#EndIf
