#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure fills image number for event 152-FZ of events log monitor.
//
Procedure SetPictureNumber(LogEvent) Export
	
	PictureNumbersEvent = PersonalDataProtectionReUse.PicturesNumbersOfEvents152FL();
	
	// Setting image number according to special rules.
	LogEvent.PictureNumber = PictureNumbersEvent[LogEvent["Event"]];
	
EndProcedure

// Procedure executes filling columns which have meaning only for the Personal data protection form.
//  
Procedure FillAdditionalEventColumns(LogEvent) Export
	
	If LogEvent.Event = "_$Access$_.Access" Then
		
		MetadataPresentation = "";
		
		For Each ArrayElement IN LogEvent.MetadataPresentation Do
			// Select the object presentation without the metadata name.
			ItemPresentationParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ArrayElement, ".");
			If ItemPresentationParts.Count() < 2 Then
				ItemPresentation = TrimAll(ItemPresentationParts[0]);
			Else
				ItemPresentation = TrimAll(ItemPresentationParts[1]);
			EndIf;
			MetadataPresentation = MetadataPresentation + ItemPresentation + ", ";
		EndDo;
		
		StringFunctionsClientServer.DeleteLatestCharInRow(MetadataPresentation, 2);
		
		LogEvent.EventInfo = MetadataPresentation;
		
	ElsIf LogEvent.Event = "_$Access$_.AccessDenied"
		  OR LogEvent.Event = "_$Session$_.Authentication"
	      OR LogEvent.Event = "_$Session$_.AuthenticationError" Then
		  
		LogEventData = "";
		If LogEvent.Data <> Undefined Then
			For Each KeyAndValue IN LogEvent.Data Do
				LogEventData = KeyAndValue.Key + ": " + KeyAndValue.Value + ", ";
			EndDo;
		EndIf;
		StringFunctionsClientServer.DeleteLatestCharInRow(LogEventData, 2);
		
		LogEvent.EventInfo = LogEventData;
		
	EndIf;

EndProcedure

// Procedure adds the columns which have meaning only for the Personal data protection form.
//  
Procedure AddAdditionalEventColumns(EventLogMonitor) Export
	
	EventLogMonitor.Columns.Add("EventInfo", New TypeDescription("String"));
	
EndProcedure

#EndRegion

#EndIf