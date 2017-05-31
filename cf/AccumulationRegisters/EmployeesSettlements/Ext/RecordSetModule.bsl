
Procedure BeforeWrite(Cancel, Replacing)
	For Each Record In ThisObject Do
		If TypeOf(ThisObject.Filter.Recorder.Value) = Type("DocumentRef.BookkeepingOperation") 
			And ValueIsNotFilled(Record.PaymentMethod) And ValueIsFilled(Record.Document) 
			And CommonAtServer.IsDocumentAttribute("PaymentMethod", Record.Document.Metadata()) Then
			Record.PaymentMethod = Record.Document.PaymentMethod;
		EndIf;
	EndDo;
EndProcedure
