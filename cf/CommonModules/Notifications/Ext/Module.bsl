Procedure AddNotification(NotificationText,NotificationEvent) Export
	
	Query = New Query;
	Query.Text = "SELECT
	             |	NotificationSettings.Object,
	             |	NotificationSettings.EMailAddress AS EMailAddress,
	             |	NotificationSettings.Presentation AS Presentation
	             |FROM
	             |	InformationRegister.NotificationSettings AS NotificationSettings
	             |WHERE
	             |	NotificationSettings.NotificationEvent = &NotificationEvent";
	Query.SetParameter("NotificationEvent",NotificationEvent);
	QueryResult = Query.Execute();
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		While Selection.Next() Do
			EMail = DataProcessors.EMail.Create();
			
		
			EMail.MailText = NotificationText;
			EMail.Subject = NotificationEvent;
			
			NewRecepient = EMail.RecipientTP.Add();
			NewRecepient.EmailAddress = Selection.EMailAddress;
			NewRecepient.Presentation = Selection.Presentation;
			NewRecepient.Object = Selection.Object;
			
			If NOT EmailModule.SendEMail(SessionParameters.CurrentUser, EMail,True) Then
				Alerts.AddAlert(NStr("en = 'There were errors during sending the e-mail.'; pl = 'Powstały błędy przy wysyłaniu maila.'"));
			EndIf;
			
		EndDo;
		
	EndIf;	
	
EndProcedure	