import { Phone, Video } from 'lucide-react'
import { Modal } from '../../components/Modal.jsx'
import { Button } from '../../components/Button.jsx'

export function CallStartModal({ open, onClose, onStart }) {
  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Позвонить"
      size="sm"
      footer={
        <Button variant="ghost" onClick={onClose}>
          Отмена
        </Button>
      }
    >
      <p style={{ margin: '0 0 16px' }}>Выберите тип звонка:</p>
      <div style={{ display: 'flex', gap: 12 }}>
        <Button
          variant="primary"
          style={{ flex: 1 }}
          onClick={() => onStart('audio')}
        >
          <Phone size={18} /> Голосовой
        </Button>
        <Button
          variant="secondary"
          style={{ flex: 1 }}
          onClick={() => onStart('video')}
        >
          <Video size={18} /> Видео
        </Button>
      </div>
    </Modal>
  )
}
