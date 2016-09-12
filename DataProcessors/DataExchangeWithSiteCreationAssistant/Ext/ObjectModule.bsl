#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Procedure RunNewDataExchangeCreationActions(Cancel) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	
	Try
		
		NewNode = ExchangePlans.ExchangeSmallBusinessSite.CreateNode();
		NewNode.SetNewCode();
		
		FillPropertyValues(NewNode, ThisObject);
		
		For Each TableRow IN PriceKinds Do
			
			NewRow = NewNode.PriceKinds.Add();
			FillPropertyValues(NewRow, TableRow);
			
		EndDo;
		
		If Not ExportToSite Then 
			
			NewNode.ImportFile = TrimAll(ImportingDirectory) + "\Orders.xml";
			
		EndIf;
		
		If ProductsExchange AND OrdersExchange Then
			
			ExchangeDescription = "Product and order exchange with WEB site";
			
		ElsIf ProductsExchange Then
			
			ExchangeDescription = "Product export on WEB site";
			
		Else
			
			ExchangeDescription = "Order exchange with WEB site";
			
		EndIf;
		
		NewNode.Description = ExchangeDescription + " (" + TrimAll(NewNode.Code) + ")";
		
		If UseScheduledJobs
			AND JobSchedule <> Undefined Then 
			
			JobID = ExchangeWithSiteScheduledJobs.CreateNewJob(NewNode.Code, NewNode.Description, JobSchedule);
			NewNode.ScheduledJobID = JobID;
			
		EndIf;
		
		NewNode.PerformFullExportingCompulsorily = True;
		
		NewNode.Write();
		
		ExchangeWithSite.UpdateSessionParameters();
		
		ExchangeNodeRef = NewNode.Ref;
		
	Except
		
		MessageText = NStr("en='Error was occurred on data exchange settings saving: ';ru='При сохранении настроек обмена данными возникла ошибка: '");
		
		DataExchangeServer.ShowMessageAboutError(MessageText + ErrorDescription(), Cancel);
		WriteLogEvent(MessageText, EventLogLevel.Error,,, ErrorDescription());
		
	EndTry;
	
	If Cancel Then
		
		RollbackTransaction();
		
	Else
		
		CommitTransaction();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf