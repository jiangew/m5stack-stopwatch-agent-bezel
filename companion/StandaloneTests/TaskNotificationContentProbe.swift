import Foundation

/// Test-only process seam: actual native adapter events in, production rich wire out.
@main struct TaskNotificationContentProbe {
    static func main() throws {
        let store=try TaskNotificationStore(directory:CommandLine.arguments[1])
        let broker=try TaskNotificationBroker(store:store,richContent:true)
        while let line=readLine() {
            let event=try JSONDecoder().decode(TaskNotificationEvent.self,from:Data(line.utf8))
            try broker.ingest(event,now:event.createdAt)
            let target=try store.load().records.first(where: {$0.event.identity==event.identity})!.id
            var card=try broker.card(now:event.createdAt)
            while card.id != target {
                try broker.handle(TaskNotificationAction(v:1,g:card.g,id:card.id,r:card.r,action:"next"),now:event.createdAt)
                card=try broker.card(now:event.createdAt)
            }
            try broker.handle(TaskNotificationAction(v:1,g:card.g,id:card.id,r:card.r,action:"read"),now:event.createdAt)
            let bytes=try JSONEncoder().encode(card)
            guard bytes.count<=512,!card.decide else {throw TaskNotificationError.invalid}
            print(String(decoding:bytes,as:UTF8.self))
        }
    }
}
