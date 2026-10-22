import Foundation
private func require(_ value:@autoclosure () throws -> Bool) rethrows { let ok=try value();assert(ok) }
@main struct ContentRegression {
    static func main() throws {
        let dir=URL(fileURLWithPath:"/private/tmp").appendingPathComponent("rich-content-\(UUID())")
        defer { try? FileManager.default.removeItem(at:dir) }
        let store=try TaskNotificationStore(directory:dir.path)
        let broker=try TaskNotificationBroker(store:store,richContent:true)
        var event=TaskNotificationEvent(eventId:"one",source:"codex",sessionId:"root",runId:"turn",requestId:"r",revision:1,createdAt:1000,leaseDeadline:16000,kind:"done",title:"优化通知页布局",model:"",detail:String(repeating:"长正文 unchanged / ",count:80),canDecide:false,state:"resolved")
        event.project="stopwatch"
        try broker.ingest(event,now:1000)
        var card=try broker.card(now:1000)
        assert(card.layout==2 && card.pos==1 && card.title==event.title && card.project=="stopwatch")
        assert(card.excerpted==true && card.detail.utf8.count<=128)
        try require(try JSONEncoder().encode(card).count<=512)
        let old=try TaskNotificationBroker(store:store)
        try require(try old.card(now:1000).layout==nil)
        var second=event;second.eventId="two";second.requestId="s";second.title="";second.detail="same";second.project=nil
        try broker.ingest(second,now:1001)
        card=try broker.card(now:1001)
        try broker.handle(TaskNotificationAction(v:1,g:card.g,id:card.id,r:card.r,action:"next",seq:1),now:1001)
        let next=try broker.card(now:1001)
        assert(next.pos==2 && next.count==2 && next.title=="未命名任务 #\(next.id)")
        try require(try store.load().records.first?.event.detail==event.detail)
        for chars in ["中", "\\\"/", "🙂", "a"] {
            var long=event;long.eventId=UUID().uuidString;long.requestId=long.eventId;long.title=String(repeating:chars,count:300);long.detail=String(repeating:chars,count:500);long.project=String(repeating:chars,count:16)
            try broker.ingest(long,now:1002)
        }
        for seq in 2...7 {
            card=try broker.card(now:1003)
            try require(try JSONEncoder().encode(card).count<=512)
            assert(card.title.utf8.count<=96 && card.detail.utf8.count<=128)
            if CommandLine.arguments.contains("--emit-wire") {print(String(decoding:try JSONEncoder().encode(card),as:UTF8.self))}
            try broker.handle(TaskNotificationAction(v:1,g:card.g,id:card.id,r:card.r,action:"next",seq:UInt32(seq)),now:1003)
        }
        var approval=event;approval.eventId="approval";approval.requestId="approval";approval.kind="approval";approval.title="Exact scope";approval.detail="pwd";approval.state="pending";approval.canDecide=true
        let cap=try TaskNotificationBroker(store:store,richContent:true);try cap.ingest(approval,now:1000)
        let native=try cap.card(now:1000);assert(native.decide && native.layout==nil && native.detail=="pwd")
        if CommandLine.arguments.contains("--emit-wire") {return}
        print("PASS rich content: Unicode, old queue/legacy opt-out, position, 512-byte budget, unmodified original body and complete approval scope")
    }
}
