import SwiftUI
import MapKit

final class RouteAnnotation: NSObject, MKAnnotation {
    let id: UUID
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    init(_ point: RoutePoint, index: Int, displayCoordinate: CLLocationCoordinate2D) { id = point.id; coordinate = displayCoordinate; title = "途经点 \(index + 1)" }
}

struct MapEditor: NSViewRepresentable {
    @ObservedObject var model: StudioModel
    func makeCoordinator() -> Coordinator { Coordinator(model) }
    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.mapType = .standard; map.showsScale = true; map.showsCompass = true
        map.pointOfInterestFilter = .excludingAll
        map.setRegion(.init(center: model.mapCoordinate(RoutePoint(latitude: 31.2304, longitude: 121.4737)), span: .init(latitudeDelta: 0.018, longitudeDelta: 0.018)), animated: false)
        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.clicked(_:)))
        click.delegate = context.coordinator; map.addGestureRecognizer(click)
        return map
    }
    func updateNSView(_ map: MKMapView, context: Context) { context.coordinator.update(map) }

    final class Coordinator: NSObject, MKMapViewDelegate, NSGestureRecognizerDelegate {
        var model: StudioModel
        var points: [RoutePoint] = []
        var closed = false
        var selection: UUID?
        var fitRevision = 0
        let playback = MKPointAnnotation()
        var playbackAdded = false
        var dragging = false
        var mainlandMap = true
        init(_ model: StudioModel) { self.model = model }
        @objc func clicked(_ gesture: NSClickGestureRecognizer) {
            guard let map = gesture.view as? MKMapView, model.editMode, !model.locked, !dragging else { return }
            let location = gesture.location(in: map)
            var view = map.hitTest(location)
            while let current = view {
                if current is MKAnnotationView { return }
                view = current.superview
            }
            model.add(model.gpsCoordinate(map.convert(location, toCoordinateFrom: map)))
        }
        func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer) -> Bool { true }
        func update(_ map: MKMapView) {
            if !dragging && (points != model.route.points || closed != model.route.closed || mainlandMap != model.mainlandMap || (model.route.points.count > 60 && selection != model.selectedPoint)) {
                mainlandMap = model.mainlandMap
                points = model.route.points; closed = model.route.closed
                map.removeAnnotations(map.annotations.filter { $0 is RouteAnnotation })
                // Dense GPX tracks remain readable: show their endpoints and the selected point.
                let visible = points.enumerated().filter { index, point in points.count <= 60 || index == 0 || index == points.count - 1 || point.id == model.selectedPoint }
                map.addAnnotations(visible.map { RouteAnnotation($0.element, index: $0.offset, displayCoordinate: model.mapCoordinate($0.element)) })
                map.removeOverlays(map.overlays)
                var coordinates = points.map { model.mapCoordinate($0) }
                if closed, let first = coordinates.first { coordinates.append(first) }
                if coordinates.count > 1 { map.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count)) }
                selection = nil
            }
            for annotation in map.annotations {
                if let point = annotation as? RouteAnnotation, let view = map.view(for: point) as? MKMarkerAnnotationView {
                    view.isDraggable = !model.locked
                    let index = points.firstIndex(where: { $0.id == point.id }) ?? 0
                    view.glyphText = points.count > 60 && index == 0 ? "起" : (points.count > 60 && index == points.count - 1 ? "终" : String(index + 1))
                    view.markerTintColor = point.id == model.selectedPoint ? .systemIndigo : (index == 0 ? .systemTeal : .systemBlue)
                }
            }
            if selection != model.selectedPoint {
                selection = model.selectedPoint
                if let selected = map.annotations.first(where: { ($0 as? RouteAnnotation)?.id == selection }) { map.selectAnnotation(selected, animated: false) }
                else { for a in map.selectedAnnotations { map.deselectAnnotation(a, animated: false) } }
            }
            if let point = model.currentPoint {
                if !playbackAdded { playback.title = "当前位置"; playbackAdded = true; map.addAnnotation(playback) }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25; playback.coordinate = model.mapCoordinate(point)
                }
            } else if playbackAdded { map.removeAnnotation(playback); playbackAdded = false }
            if let focus = model.focusRequest {
                map.setRegion(.init(center: focus, span: .init(latitudeDelta: 0.006, longitudeDelta: 0.006)), animated: true)
                DispatchQueue.main.async { [weak self] in self?.model.focusRequest = nil }
            }
            if fitRevision != model.fitRevision {
                fitRevision = model.fitRevision
                var rect = MKMapRect.null
                for p in points { let point = MKMapPoint(model.mapCoordinate(p)); rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1)) }
                if !rect.isNull { map.setVisibleMapRect(rect, edgePadding: NSEdgeInsets(top: 100, left: 80, bottom: 90, right: 80), animated: true) }
            }
        }
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemTeal; renderer.lineWidth = 5; renderer.lineCap = .round; renderer.lineJoin = .round
            return renderer
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation === playback {
                let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "playback")
                let image = NSImage(size: NSSize(width: 30, height: 30), flipped: false) { rect in
                    NSColor.systemTeal.withAlphaComponent(0.2).setFill(); NSBezierPath(ovalIn: rect).fill()
                    NSColor.white.setFill(); NSBezierPath(ovalIn: rect.insetBy(dx: 5, dy: 5)).fill()
                    NSColor.systemTeal.setFill(); NSBezierPath(ovalIn: rect.insetBy(dx: 8, dy: 8)).fill(); return true
                }
                view.image = image; view.displayPriority = .required; view.zPriority = .max
                return view
            }
            guard let route = annotation as? RouteAnnotation else { return nil }
            let view = MKMarkerAnnotationView(annotation: route, reuseIdentifier: "point")
            view.canShowCallout = false; view.isDraggable = !model.locked; view.displayPriority = .required
            let index = model.route.points.firstIndex(where: { $0.id == route.id }) ?? 0
            view.glyphText = model.route.points.count > 60 && index == 0 ? "起" : (model.route.points.count > 60 && index == model.route.points.count - 1 ? "终" : String(index + 1)); view.markerTintColor = index == 0 ? .systemTeal : .systemBlue
            return view
        }
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let route = view.annotation as? RouteAnnotation { model.selectedPoint = route.id }
        }
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            if newState == .starting { dragging = true; view.dragState = .dragging }
            if newState == .ending || newState == .canceling {
                if let annotation = view.annotation as? RouteAnnotation, newState == .ending { model.move(annotation.id, to: model.gpsCoordinate(annotation.coordinate)) }
                dragging = false; view.dragState = .none
            }
        }
    }
}
